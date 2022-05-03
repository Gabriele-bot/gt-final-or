
-- Description:
-- Testbench for prescalers (P2GT FinalOR) with fractional prescale values

-- Created by Gabriele Bortolato 14-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware)

-- Version history:
-- GB 14-03-2022: first design

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pre_scaler_pkg.all;

entity algo_pre_scaler_tb is
end algo_pre_scaler_tb;

architecture behav of algo_pre_scaler_tb is

    constant SIM : boolean := true;

    constant PRESCALE_FACTOR_VALUE         : real := 2.48;
    constant PRESCALE_FACTOR_VALUE_INTEGER : integer               := integer(PRESCALE_FACTOR_VALUE * real(10**PRESCALE_FACTOR_FRACTION_DIGITS));
    constant PRESCALE_FACTOR_VALUE_UNSGND  : unsigned(31 downto 0) := to_unsigned(PRESCALE_FACTOR_VALUE_INTEGER, PRESCALE_FACTOR_WIDTH);

    constant LHC_CLK_PERIOD  : time :=  25 ns;

    signal lhc_clk   : std_logic;
    signal sres_counter, request_update_factor_pulse, update_factor_pulse : std_logic := '0';
    signal algo      : std_logic := '1';
    signal algo_o    : std_logic;

    signal prescale_factor : std_logic_vector(PRESCALE_FACTOR_WIDTH-1 downto 0) := (others => '0');

    signal index_sim              : integer;
    signal algo_cnt_sim           : natural;
    signal prescaled_algo_cnt_sim : natural;

    --*********************************Main Body of Code**********************************
begin

    -- Clock
    process
    begin
        lhc_clk  <=  '1';
        wait for LHC_CLK_PERIOD/2;
        lhc_clk  <=  '0';
        wait for LHC_CLK_PERIOD/2;
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

    -- Prescale factor update
    process
    begin
        wait for LHC_CLK_PERIOD;
        prescale_factor <= std_logic_vector(PRESCALE_FACTOR_VALUE_UNSGND);
        wait for 5*LHC_CLK_PERIOD;
        request_update_factor_pulse <= '1';
        wait for LHC_CLK_PERIOD;
        request_update_factor_pulse <= '0';
        wait for 5*LHC_CLK_PERIOD;
        update_factor_pulse <= '1';
        wait for LHC_CLK_PERIOD;
        update_factor_pulse <= '0';
        wait;
    end process;

    ------------------- Instantiate  modules  -----------------

    dut: entity work.algo_pre_scaler
        generic map(PRESCALE_FACTOR_WIDTH => 32,
                    PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT_VALUE_UNSGND,
                    SIM                   => SIM
                   )
        port map(
            clk                         => lhc_clk,
            sres_counter                => sres_counter,
            algo_i                      => algo,
            request_update_factor_pulse => request_update_factor_pulse,
            update_factor_pulse         => update_factor_pulse,
            prescale_factor             => prescale_factor,
            prescaled_algo_o            => algo_o,
            prescaled_algo_cnt_sim      => prescaled_algo_cnt_sim,
            algo_cnt_sim                => algo_cnt_sim
        );

end behav;
