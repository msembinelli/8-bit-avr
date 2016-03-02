-------------------------------------------------------------------------------
--
-- Module Name: opc_fetch
-- Create Date: 11/30/2014
-- Description: 
--
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity opc_fetch is
    port (  I_CLK      : in  std_logic;
            I_CLR      : in  std_logic;
            I_INTVEC   : in  std_logic_vector( 5 downto 0);   --Interrupt vector, top bit gets ANDed w/ R_INT_ENA
            I_NEW_PC   : in  std_logic_vector(15 downto 0);   --New PC as the result of branch or jump
            I_PM_ADR   : in  std_logic_vector(11 downto 0);   --12 bit address input to program memory
		    I_SKIP     : in  std_logic;                       --SKIP will be used to invalidate instructions still in the pipeline
		    I_LOAD_PC  : in  std_logic;                       --Load New PC into I_NEXT_PC enable bit
		   
		    Q_PC       : out std_logic_vector(15 downto 0);   --Current program counter to decoder
		    Q_OPC      : out std_logic_vector(31 downto 0);   --Opcode into decoder
		    Q_PM_DOUT  : out std_logic_vector( 7 downto 0);   --Program memory out to mux
		    Q_T0       : out std_logic	);                    --TODO
end opc_fetch;

architecture Behavioral of opc_fetch is

component prog_mem                                            -- Dual port memory
    port (  I_CLK      : in  std_logic;                       
            I_WAIT     : in  std_logic;                       
            I_PC       : in  std_logic_vector(15 downto 0);   --
			I_PM_ADR   : in  std_logic_vector(11 downto 0);   --
			
			Q_OPC      : out std_logic_vector(31 downto 0);   --
			Q_PC       : out std_logic_vector(15 downto 0);   --
			Q_PM_DOUT  : out std_logic_vector( 7 downto 0) ); --
end component;

signal P_OPC           :     std_logic_vector(31 downto 0);
signal P_PC            :     std_logic_vector(15 downto 0);		

signal L_INVALIDATE    :     std_logic;
signal L_LONG_OP       :     std_logic;
signal L_NEXT_PC       :     std_logic_vector(15 downto 0);
signal L_PC            :     std_logic_vector(15 downto 0);
signal L_T0            :     std_logic;
signal L_WAIT          :     std_logic;

begin

    pmem : prog_mem
	port map( I_CLK     => I_CLK,
	          I_WAIT    => L_WAIT,
			  I_PC      => L_NEXT_PC,
			  I_PM_ADR  => I_PM_ADR,
			  
			  Q_OPC     => P_OPC,
			  Q_PC      => P_PC,
			  Q_PM_DOUT => Q_PM_DOUT );


    lpc: process(I_CLK)
	begin
		if (rising_edge(I_CLK)) then
			L_PC <= L_NEXT_PC;
		    L_T0 <= not L_WAIT;
		end if;
	end process;
	
	L_INVALIDATE <= I_CLR or I_SKIP;
	
    L_NEXT_PC <= X"0000"         when (I_CLR     = '1')
		else L_PC            when (L_WAIT    = '1')
		else I_NEW_PC        when (I_LOAD_PC = '1')
		else L_PC + X"0002"  when (L_LONG_OP = '1')
		else L_PC + X"0001";
				
	-- Two word opcodes:
	--        9       3210
	-- 1001 000d dddd 0000 kkkk kkkk kkkk kkkk - LDS
	-- 1001 001d dddd 0000 kkkk kkkk kkkk kkkk - SDS
	-- 1001 010k kkkk 110k kkkk kkkk kkkk kkkk - JMP
	-- 1001 010k kkkk 111k kkkk kkkk kkkk kkkk - CALL
				
	L_LONG_OP <= '1' when (((P_OPC(15 downto  9) = "1001010") and
		                    (P_OPC( 3 downto  2) = "11"))          --JMP, CALL
					   or  ((P_OPC(15 downto 10) = "100100") and
						    (P_OPC( 3 downto  0) = "0000")))       --LDS, STS
				         else '0';
						 
	--Two cycle opcodes:
	--1001 000d .... - LDS etc.
	--1001 0101 0000 1000 - RET
	--1001 0101 0001 1000 - RETI
	--1001 1001 AAAA Abbb - SBIC
	--1001 1011 AAAA Abbb - SBIS
	--1111 110r rrrr 0bbb - SBRC
	--1111 111r rrrr 0bbb - SBRS
	
	L_WAIT <= '0' when (L_INVALIDATE = '1')
	    else  '0' when (I_INTVEC(5)  = '1')
		else L_T0 when ((P_OPC(15 downto  9) = "1001000" )         --LDS etc.
		            or  (P_OPC(15 downto  8) = "10010101")         --RET etc.
					or ((P_OPC(15 downto 10) = "100110"  )         --SBIC, SBIS
				   and   P_OPC(8) = '1')
				    or (P_OPC(15 downto 10) = "111111"  ))         --SBRC, SBRS
					
						 
		
	Q_OPC <= X"00000000" when (L_INVALIDATE = '1')
		else P_OPC       when (I_INTVEC(5) = '0')
	    else (X"000000" & "00" & I_INTVEC);            --interrupt opcode
		
	Q_PC <= P_PC;
	Q_T0 <= L_T0;
	
end Behavioral;