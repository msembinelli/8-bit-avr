-------------------------------------------------------------------------------
--
-- Module Name: avr_fpga - Behavioral
-- Create Date: 11/30/2014
-- Description: top level of a CPU
--
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity avr_fpga is
        port ( I_CLK_50   : in  std_logic;                      --Input from 50MHz Clock
	           I_SWITCH   : in  std_logic_vector(5 downto 0);   --Input from 4 DIP switches
		       I_RX       : in  std_logic;                      --UART Rx
		   
		       O_LED_PC   : out std_logic_vector(3 downto 0);   --Upper 4 LEDS for PC Debug
		       O_LEDS     : out std_logic_vector(3 downto 0);   --Bottom 4 LEDS for misc
		       O_TX       : out std_logic; );                   --UART Tx
		   
architecture Behavioral of avr_fpga is
    
	component cpu_core
	    port ( I_CLK      : in  std_logic;                      --50MHz Clock to cpu_core
		       I_CLR      : in  std_logic;                      --cpu_core Clear
			   I_INTVEC   : in  std_logic_vector( 5 downto 0);  --6 Interrupt Vectors
			   I_DIN      : in  std_logic_vector( 7 downto 0);  --Data in, 8-bit word
			   
			   O_OPC      : out std_logic_vector(15 downto 0);  --Program counter output?(TODO)
			   O_PC       : out std_logic_vector(15 downto 0);  --Program counter? (TODO)
			   O_DOUT     : out std_logic_vector( 7 downto 0);  --Data out, 8-bit word
			   O_ADR_IO   : out std_logic_vector( 7 downto 0);  --Address used to access memory
			   O_RD_IO    : out std_logic;                      --Read enable for dual port memory
			   O_WE_IO    : out std_logic);                     --Write enable for dual port memory
	end component;
	
	signal C_PC           :     std_logic_vector(15 downto 0);
	signal C_OPC          :     std_logic_vector(15 downto 0);
	signal C_ADR_IO       :     std_logic_vector( 7 downto 0);
	signal C_DOUT         :     std_logic_vector( 7 downto 0);
	signal C_RD_IO        :     std_logic;
	signal C_WE_IO        :     std_logic;
	
    component io
	    port ( I_CLK      : in  std_logic;                      --50MHz Clock to io
		       I_CLR      : in  std_logic;                      --io Clear
			   I_ADR_IO   : in  std_logic_vector( 7 downto 0);  --Address in from cpu_core
			   I_DIN      : in  std_logic_vector( 7 downto 0);  --Data in from cpu_core
			   I_RD_IO    : in  std_logic;                      --Read enable from cpu_core
			   I_WE_IO    : in  std_logic;                      --Write enable from cpu_core
			   I_SWITCH   : in  std_logic_vector( 5 downto 0);  --Input switches from avr_fpga
			   I_RX       : in  std_logic;
			   
			   O_LED_PC   : out std_logic_vector( 3 downto 0);  --4 LEDS for displaying PC data
			   O_DOUT     : out std_logic_vector( 7 downto 0);  --Output data from io to cpu core
			   O_INTVEC   : out std_logic_vector( 5 downto 0);  --Output interrupt vector
			   O_LEDS     : out std_logic_vector( 1 downto 0);  --Rx and Tx UART LEDs? (TODO)
			   O_TX       : out std_logic);                     --Tx UART to avr_fpga
    end component;
	
	signal N_INTVEC       :     std_logic_vector( 5 downto 0);
	signal N_DOUT         :     std_logic_vector( 7 downto 0);
	signal N_TX           :     std_logic;
	signal N_LED_PC       :     std_logic_vector( 3 downto 0);
	
	component led_disp
	    port ( I_CLK      : in  std_logic;                      --50MHz Clock to led_disp
			   I_CLR      : in  std_logic;                      --led_disp Clear
			   I_OPC      : in  std_logic_vector(15 downto 0);  --TODO
			   I_PC       : in  std_logic_vector(15 downto 0);  --TODO
			   
			   O_LED_PC   : out std_logic_vector( 3 downto 0) );--One hex digit output of PC
	end component;
	
	signal S_LED_PC       :     std_logic_vector( 3 downto 0);  --Bridge O_LED_PC to hardware
	
	--Local signals
	signal L_CLK          :     std_logic := '0';
	signal L_CLK_CNT      :     std_logic_vector( 1 downto 0) := "00";
	signal L_CLR          :     std_logic;                      --Reset, active low
	signal L_CLR_N        :     std_logic := '0';               --Reset, active low
	signal L_C1_N         :     std_logic := '0';               --Switch debounce, active low
	signal L_C2_N         :     std_logic := '0';               --Switch debounce, active low
	
	begin
	
	cpu : cpu_core
	port map ( I_CLK      => L_CLK,
		       I_CLR      => L_CLR,
			   I_DIN      => N_DOUT,
			   I_INTVEC   => N_INTVEC,
				   
			   O_ADR_IO   => C_ADR_IO,
			   O_DOUT     => C_DOUT,
			   O_OPC      => C_OPC,
			   O_PC       => C_PC,
			   O_RD_IO    => C_RD_IO,
			   O_WE_IO    => C_WE_IO );
			   
    ino : io
	port map ( I_CLK      => L_CLK,
		       I_CLR      => L_CLR,
			   I_ADR_IO   => C_ADR_IO,
			   I_DIN      => C_DOUT,
			   I_RD_IO    => C_RD_IO,
			   I_RX       => I_RX,
			   I_SWITCH   => I_SWITCH( 3 downto 0),
			   I_WE_IO    => C_WE_IO,
			   
			   Q_LED_PC   => N_LED_PC,
			   Q_DOUT     => N_DOUT,
			   Q_INTVEC   => N_INTVEC,
			   Q_LEDS     => Q_LEDS( 1 downto 0);
			   Q_TX       => N_TX );
			   
	disp : led_disp
	port map ( I_CLK      => L_CLK,
	           I_CLR      => L_CLR,
			   I_OPC      => C_OPC,
			   I_PC       => C_PC,
			   
			   Q_LED_PC   => S_LED_PC );
			   
	clk_div : process(I_CLK_50)   --TODO: Check if this is correct
	begin
	    if (rising_edge(I_CLK_50)) then 
		    L_CLK_CNT <= L_CLK_CNT + 1;
			if (L_CLK_CNT = "00") then 
				L_CLK     <= not L_CLK;
			else
			    L_CLK     <=L_CLK;
		    end if;
	    end if;
	end process;
	
    L_CLR     <= I_SWITCH(5);
	Q_LEDS(2) <= I_RX;                                          --UART Rx LED
	Q_LEDS(3) <= N_TX;                                          --UART Tx LED
	Q_LED_PC  <= N_LED_PC when (I_SWITCH(3) = '1') 
	                      else S_LED_PC;
	Q_TX      <= N_TX;
				   
	
end Behavioral;