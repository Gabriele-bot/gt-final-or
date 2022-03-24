library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity algo_rate_counter_tb is
end entity algo_rate_counter_tb;

architecture RTL of algo_rate_counter_tb is

    constant RATE_COUNTER_WIDTH : integer := 32;

    constant SYS_CLK_PERIOD  : time :=  8  ns;
    constant LHC_CLK_PERIOD  : time :=  25 ns;

    -- inputs
    signal lhc_clk, sys_clk : std_logic;
    signal sres_counter     : std_logic := '0';
    signal store_cnt_value  : std_logic := '0';
    signal algo             : std_logic := '1';

    -- ouptus
    signal counter_o : std_logic_vector(RATE_COUNTER_WIDTH - 1 downto 0);



    --*********************************Main Body of Code**********************************
begin


    -- Clock
    process
    begin
        sys_clk  <=  '1';
        wait for SYS_CLK_PERIOD/2;
        sys_clk  <=  '0';
        wait for SYS_CLK_PERIOD/2;
    end process;

    -- Clock
    process
    begin
        lhc_clk  <=  '1';
        wait for LHC_CLK_PERIOD/2;
        lhc_clk  <=  '0';
        wait for LHC_CLK_PERIOD/2;
    end process;

    -- Store value
    process
    begin
        store_cnt_value <= '0';
        wait for 500*LHC_CLK_PERIOD;
        store_cnt_value <= '1';
        wait for LHC_CLK_PERIOD;
    end process;

    -- Algo
    process
    begin
        algo  <=  '0';
        wait for 50*LHC_CLK_PERIOD;
        for i in 0 to 50 loop
            algo  <=  '1';
            wait for LHC_CLK_PERIOD;
            algo  <=  '0';
            wait for 4*LHC_CLK_PERIOD;
        end loop;
        for i in 0 to 50 loop
            algo  <=  '1';
            wait for LHC_CLK_PERIOD;
            algo  <=  '0';
            wait for 3*LHC_CLK_PERIOD;
        end loop;
        for i in 0 to 50 loop
            algo  <=  '1';
            wait for LHC_CLK_PERIOD;
            algo  <=  '0';
            wait for 2*LHC_CLK_PERIOD;
        end loop;
        for i in 0 to 50 loop
            algo  <=  '1';
            wait for LHC_CLK_PERIOD;
            algo  <=  '0';
            wait for LHC_CLK_PERIOD;
        end loop;
    end process;



    ------------------- Instantiate  modules  -----------------

    dut : entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            sys_clk         => sys_clk,
            lhc_clk         => lhc_clk,
            sres_counter    => sres_counter,
            store_cnt_value => store_cnt_value,
            algo_i          => algo,
            counter_o       => counter_o
        );
end architecture RTL;
