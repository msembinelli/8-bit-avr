-------------------------------------------------------------------------------
--
-- Module Name: cpu_core - Behavioral
-- Create Date: 11/30/2014
-- Description: 
--
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cpu_core is
	port (  I_CLK      : in  std_logic;                      --50MHz Clock to cpu_core
		    I_CLR      : in  std_logic;                      --cpu_core Clear
		    I_INTVEC   : in  std_logic_vector( 5 downto 0);  --6 Interrupt Vectors
		    I_DIN      : in  std_logic_vector( 7 downto 0);  --Data in, 8-bit word
			   
		    O_OPC      : out std_logic_vector(15 downto 0);  --Program counter output?(TODO)
		    O_PC       : out std_logic_vector(15 downto 0);  --Program counter? (TODO)
		    O_DOUT     : out std_logic_vector( 7 downto 0);  --Data out, 8-bit word
		    O_ADR_IO   : out std_logic_vector( 7 downto 0);  --Address used to access memory
		    O_RD_IO    : out std_logic;                      --Read enable for dual port memory
		    O_WE_IO    : out std_logic  );                   --Write enable for dual port memory

end cpu_core;

architecture Behavioral of cpu_core is

component opc_fetch
    port (  I_CLK      : in  std_logic;
            I_CLR      : in  std_logic;
            I_INTVEC   : in  std_logic_vector( 5 downto 0);  --Interrupt vector, top bit gets ANDed w/ R_INT_ENA
            I_NEW_PC   : in  std_logic_vector(15 downto 0);  --New PC as the result of branch or jump
            I_PM_ADR   : in  std_logic_vector(11 downto 0);  --12 bit address input to program memory
		    I_SKIP     : in  std_logic;                      --SKIP will be used to invalidate instructions still in the pipeline
		    I_LOAD_PC  : in  std_logic;                      --Load New PC into I_NEXT_PC enable bit
		   
		    Q_PC       : out std_logic_vector(15 downto 0);  --Current program counter to decoder
		    Q_OPC      : out std_logic_vector(31 downto 0);  --Opcode into decoder
		    Q_PM_DOUT  : out std_logic_vector( 7 downto 0);  --Program memory out to mux
		    Q_T0       : out std_logic  );                   --For 2 cycle instructions, to know when they are done
end component;

signal F_PC            :     std_logic_vector(15 downto 0);
signal F_OPC           :     std_logic_vector(31 downto 0);
signal F_PM_DOUT       :     std_logic_vector( 7 downto 0);
signal F_T0            :     std_logic;

component opc_deco
    port (  I_CLK      : in  std_logic;
            I_OPC      : in  std_logic_vector(31 downto 0);
            I_PC       : in  std_logic_vector(15 downto 0);
            I_T0       : in  std_logic;

            Q_ALU_OP   : out std_logic_vector( 4 downto 0);  -- Tells ALU what operation to perform
			Q_AMOD     : out std_logic_vector( 5 downto 0);  -- Memory addressing mode to be used for data accesses
			Q_BIT      : out std_logic_vector( 3 downto 0);  -- Bit number used in bit instructions ??
			Q_DDDDD    : out std_logic_vector( 4 downto 0);  -- Bits used to select destination register, and first source register
			Q_IMM      : out std_logic_vector(15 downto 0);  -- 16 bit immediate number
			Q_JADR     : out std_logic_vector(15 downto 0);  -- 16 bit jump/branch address
			Q_OPC      : out std_logic_vector(15 downto 0);  -- Opcode being decoded
			Q_PC       : out std_logic_vector(15 downto 0);  -- Current program counter address (useful for calculating branches in ALU)
			Q_PC_OP    : out std_logic_vector( 2 downto 0);  -- Defines operation to be performed on PC
			Q_PMS      : out std_logic;                      -- Program memory select/Data memory select
			Q_RD_M     : out std_logic;                      -- Read from data memory select
			Q_RRRRR    : out std_logic_vector( 4 downto 0);  -- Bits used to select second register
			Q_RSEL     : out std_logic_vector( 1 downto 0);  -- Source of second operand in ALU, (R, IMM, or DIN)
			Q_WE_01    : out std_logic;                      -- Used for instructions that store result in pair rather than single reg
			Q_WE_D     : out std_logic_vector( 1 downto 0);  -- ?? TODO
			Q_WE_F     : out std_logic;                      -- Set when status registers shall be written
			Q_WE_M     : out std_logic_vector( 1 downto 0);  -- Set when memory shall be written
			Q_WE_XYZS  : out std_logic  );                   -- Set when the stack pointer or one of the pointer register pairs X, Y, or Z shall be written.
end component;

signal D_ALU_OP        :     std_logic_vector( 4 downto 0);
signal D_AMOD          :     std_logic_vector( 5 downto 0);
signal D_BIT           :     std_logic_vector( 3 downto 0);
signal D_DDDDD         :     std_logic_vector( 4 downto 0);
signal D_IMM           :     std_logic_vector(15 downto 0);
signal D_JADR          :     std_logic_vector(15 downto 0);
signal D_OPC           :     std_logic_vector(15 downto 0);
signal D_PC            :     std_logic_vector(15 downto 0);
signal D_PC_OP         :     std_logic_vector( 2 downto 0);
signal D_PMS           :     std_logic;
signal D_RD_M          :     std_logic;
signal D_RRRR          :     std_logic_vector( 4 downto 0);
signal D_RSEL          :     std_logic_vector( 1 downto 0);
signal D_WE_01         :     std_logic; 
signal D_WE_D          :     std_logic_vector( 1 downto 0); 
signal D_WE_F          :     std_logic; 
signal D_WE_M          :     std_logic_vector( 1 downto 0);
signal D_WE_XYZS       :     std_logic;

component data_path
    port (  I_CLK      : in  std_logic;
	        I_ALU_OP   : in  std_logic_vector( 4 downto 0);
			I_AMOD     : in  std_logic_vector( 5 downto 0);
			I_BIT      : in  std_logic_vector( 3 downto 0);
			I_DDDDD    : in  std_logic_vector( 4 downto 0);
			I_DIN      : in  std_logic_vector( 7 downto 0);
			I_IMM      : in  std_logic_vector(15 downto 0);
			I_JADR     : in  std_logic_vector(15 downto 0);
			I_PC_OP    : in  std_logic_vector( 2 downto 0);
			I_OPC      : in  std_logic_vector(15 downto 0);
			I_PC       : in  std_logic_vector(15 downto 0);
			I_PMS      : in  std_logic;
			I_RD_M     : in  std_logic;
			I_RRRRR    : in  std_logic_vector( 4 downto 0);
			I_RSEL     : in  std_logic_vector( 1 downto 0);
			I_WE_01    : in  std_logic;
			I_WE_D     : in  std_logic_vector( 1 downto 0);
			I_WE_F     : in  std_logic;
			I_WE_M     : in  std_logic_vector( 1 downto 0);
			I_WE_XYZS  : in  std_logic;
			
			Q_ADR      : out std_logic_vector(15 downto 0);
			Q_DOUT     : out std_logic_vector( 7 downto 0);
			Q_INT_ENA  : out std_logic;
			Q_LOAD_PC  : out std_logic;
			Q_NEW_PC   : out std_logic_vector(15 downto 0);
            Q_OPC      : out std_logic_vector(15 downto 0);
			Q_PC       : out std_logic_vector(15 downto 0);
			Q_RD_IO    : out std_logic;
			Q_SKIP     : out std_logic;
			Q_WE_IO    : out std_logic  );
end component;


signal R_INT_ENA       :     std_logic;
signal R_NEW_PC        :     std_logic_vector(15 downto 0);
signal R_LOAD_PC       :     std_logic;
signal R_SKIP          :     std_logic;
signal R_ADR           :     std_logic_vector(15 downto 0);

--local signals
signal L_DIN           :     std_logic_vector( 7 downto 0);
signal L_INTVEC_5      :     std_logic;

begin

    opcf : opc_fetch
	port map( I_CLK                => I_CLK,
	          I_CLR                => I_CLR,
			  I_INTVEC(5)          => L_INTVEC_5,
			  I_INTVEC(4 downto 0) => I_INTVEC(4 downto 0),
			  I_LOAD_PC            => R_LOAD_PC,
			  I_NEW_PC             => R_NEW_PC,
			  I_PM_ADR             => R_ADR(11 downto 0),
			  I_SKIP               => R_SKIP,
			  
			  Q_PC                 => F_PC,
			  Q_OPC                => F_OPC,
			  Q_T0                 => F_T0,
			  Q_PM_DOUT            => F_PM_DOUT );
			  
	odec : opc_deco
	port map( I_CLK                => I_CLK,
	          I_OPC                => F_OPC,
			  I_PC                 => F_PC,
			  I_T0                 => F_T0,
			  
			  Q_ALU_OP             => D_ALU_OP,
			  Q_AMOD               => D_AMOD,
			  Q_BIT                => D_BIT,
			  Q_DDDDD              => D_DDDDD,
			  Q_IMM                => D_IMM,
			  Q_JADR               => D_JADR,
			  Q_OPC                => D_OPC,
			  Q_PC                 => D_PC,
			  Q_PC_OP              => D_PC_OP,
			  Q_PMS                => D_RD_M,
			  Q_RRRRR              => D_RRRRR,
			  Q_RSEL               => D_RSEL,
			  Q_WE_01              => D_WE_01,
			  Q_WE_D               => D_WE_D,
			  Q_WE_F               => D_WE_F,
			  Q_WE_M               => D_WE_M
			  Q_WE_XYZS            => D_WE_XYZS );
			  
	dpath : data_path
	port map( I_CLK                => I_CLK,
	          I_ALU_OP             => D_ALU_OP,
			  I_AMOD               => D_AMOD,
			  I_BIT                => D_BIT,
			  I_DDDDD              => D_DDDDD,
			  I_DIN                => L_DIN
			  I_IMM                => D_IMM,
			  I_JADR               => D_JADR,
			  I_OPC                => D_OPC,
			  I_PC                 => D_PC,
			  I_PC_OP              => D_PC_OP,
			  I_PMS                => D_PMS,
			  I_RD_M               => D_RD_M,
			  I_RRRRR              => D_RRRRR,
			  I_RSEL               => D_RSEL,
			  I_WE_01              => D_WE_01,
			  I_WE_D               => D_WE_D,
			  I_WE_F               => D_WE_F,
			  I_WE_M               => D_WE_M,
			  I_WE_XYZS            => D_WE_XYZS,
			  
			  Q_ADR                => R_ADR,
			  Q_DOUT               => Q_DOUT,
			  Q_INT_ENA            => R_INT_ENA,
			  Q_NEW_PC             => R_NEW_PC,
			  Q_OPC                => Q_OPC,
			  Q_PC                 => Q_PC,
			  Q_LOAD_PC            => R_LOAD_PC,
			  Q_RD_IO              => Q_RD_IO,
			  Q_SKIP               => R_SKIP,
			  Q_WE_IO              => Q_WE_IO );
			  
	L_DIN       <= F_PM_DOUT when (D_PMS = '1') else I_DIN( 7 downto 0);
    L_INTVEC_5  <= I_INTVEC(5) and R_INT_ENA;
	Q_ADR_IO    <= R_ADR(7 downto 0);
	
end Behavioral;