library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay_element_ringbuffer_tb is
end entity delay_element_ringbuffer_tb;

architecture RTL of delay_element_ringbuffer_tb is

    constant CLK_X9_PERIOD   : time := 2.778 ns;
    constant LHC_CLK_PERIOD  : time := CLK_X9_PERIOD*9;

    signal clk_x9  : std_logic;
    signal rst_x9  : std_logic;
    signal lhc_clk : std_logic;
    signal data_i  : std_logic_vector(63 downto 0) := (others => '0');
    signal data_o  : std_logic_vector(63 downto 0) := (others => '0');
    signal delay_int   : integer := 18*9;
    signal delay : std_logic_vector(9 downto 0);

begin

    delay <= std_logic_vector(to_unsigned(delay_int, 10));


    -- Clock
    process
    begin
        clk_x9  <=  '1';
        wait for CLK_X9_PERIOD/2;
        clk_x9  <=  '0';
        wait for CLK_X9_PERIOD/2;
    end process;
    
    -- Clock
    process
    begin
        lhc_clk  <=  '1';
        wait for LHC_CLK_PERIOD/2;
        lhc_clk  <=  '0';
        wait for LHC_CLK_PERIOD/2;
    end process;
    

    -- Reset
    process
    begin
        rst_x9  <=  '1';
        wait for CLK_X9_PERIOD;
        rst_x9  <=  '1';
        wait for 8*CLK_X9_PERIOD;
        rst_x9  <=  '0';
        wait;
    end process;

    -- data_i
    process
    begin
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(1, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(1, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(1, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(1, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(1, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(1, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(1, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for CLK_X9_PERIOD;
        data_i  <=  std_logic_vector(to_unsigned(0, 64));
        wait for 20*CLK_X9_PERIOD;
    end process;


    dut : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => 64,
            MAX_DELAY  => 63*9
        )
        port map(
            clk    => clk_x9,
            rst    => rst_x9,
            data_i => data_i,
            data_o => data_o,
            delay  => delay
        );

end architecture RTL;
