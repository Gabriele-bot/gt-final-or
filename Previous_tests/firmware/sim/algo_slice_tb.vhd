

-- Description:
-- Testbench for algo_slice module (P2GT FinalOR).

-- Created by Gabriele Bortolato 14-03-2022

-- Version history:
-- GB 14-03-2022: first design



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pre_scaler_pkg.all;


entity algo_slice_tb is
end entity algo_slice_tb;

architecture behav of algo_slice_tb is

    constant RATE_COUNTER_WIDTH : integer := 32;

    constant PRESCALE_FACTOR_VALUE         : real                  := 2.48;
    constant PRESCALE_FACTOR_VALUE_INTEGER : integer               := integer(PRESCALE_FACTOR_VALUE * real(10**PRESCALE_FACTOR_FRACTION_DIGITS));
    constant PRESCALE_FACTOR_VALUE_UNSGND  : unsigned(31 downto 0) := to_unsigned(PRESCALE_FACTOR_VALUE_INTEGER, PRESCALE_FACTOR_WIDTH);

    constant PRESCALE_FACTOR_VALUE_PRVW         : real                  := 4.87;
    constant PRESCALE_FACTOR_VALUE_PRVW_INTEGER : integer               := integer(PRESCALE_FACTOR_VALUE_PRVW * real(10**PRESCALE_FACTOR_FRACTION_DIGITS));
    constant PRESCALE_FACTOR_VALUE_PRVW_UNSGND  : unsigned(31 downto 0) := to_unsigned(PRESCALE_FACTOR_VALUE_PRVW_INTEGER, PRESCALE_FACTOR_WIDTH);

    constant SYS_CLK_PERIOD  : time :=  8  ns;
    constant LHC_CLK_PERIOD  : time :=  25 ns;

    signal sys_clk   : std_logic;
    signal lhc_clk   : std_logic;
    signal lhc_rst   : std_logic;

    signal sres_algo_rate_counter, sres_algo_pre_scaler, sres_algo_post_dead_time_counter : std_logic;
    signal suppress_cal_trigger, l1a : std_logic;
    signal begin_lumi_per : std_logic;
    signal request_update_factor_pulse : std_logic := '0';
    signal algo_i    : std_logic := '1';
    signal prescale_factor, prescale_factor_preview : std_logic_vector(PRESCALE_FACTOR_WIDTH-1 downto 0) := (others => '0');
    signal algo_bx_mask, veto_mask : std_logic;
    signal rate_cnt_after_prescaler, rate_cnt_after_prescaler_preview : std_logic_vector(RATE_COUNTER_WIDTH-1 downto 0);
    signal rate_cnt_post_dead_time, rate_cnt_before_prescaler         : std_logic_vector(RATE_COUNTER_WIDTH-1 downto 0);
    signal algo_after_bxomask, algo_after_prescaler, algo_after_prescaler_preview : std_logic;
    signal veto : std_logic;

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


    -- Reset
    process
    begin
        lhc_rst  <=  '0';
        sres_algo_rate_counter <= '0';
        sres_algo_pre_scaler   <= '0';
        sres_algo_post_dead_time_counter <='0';
        wait for 4*LHC_CLK_PERIOD;
        lhc_rst  <=  '1';
        wait for 5*LHC_CLK_PERIOD;
        lhc_rst  <=  '0';
        wait;
    end process;

    -- l1a
    process
    begin
        l1a <= '0';
        wait for 5*LHC_CLK_PERIOD;
        l1a <= '1';
        wait for 50*LHC_CLK_PERIOD;
    end process;

    -- Algo
    process
    begin
        algo_i  <=  '0';
        wait for 50*LHC_CLK_PERIOD;
        for i in 0 to 100 loop
            algo_i  <=  '1';
            wait for LHC_CLK_PERIOD;
            algo_i  <=  '0';
            wait for 8*LHC_CLK_PERIOD;
        end loop;
        for i in 0 to 100 loop
            algo_i  <=  '1';
            wait for LHC_CLK_PERIOD;
            algo_i  <=  '0';
            wait for 6*LHC_CLK_PERIOD;
        end loop;
        for i in 0 to 100 loop
            algo_i  <=  '1';
            wait for LHC_CLK_PERIOD;
            algo_i  <=  '0';
            wait for 3*LHC_CLK_PERIOD;
        end loop;
        for i in 0 to 100 loop
            algo_i  <=  '1';
            wait for LHC_CLK_PERIOD;
            algo_i  <=  '0';
            wait for 2*LHC_CLK_PERIOD;
        end loop;
        wait for 50*LHC_CLK_PERIOD;
    end process;

    -- prescale factor value update
    process
    begin
        wait for LHC_CLK_PERIOD;
        prescale_factor <= std_logic_vector(PRESCALE_FACTOR_VALUE_UNSGND);
        wait for 10*LHC_CLK_PERIOD;
        request_update_factor_pulse <= '1';
        wait for LHC_CLK_PERIOD;
        request_update_factor_pulse <= '0';
        wait for 2000*LHC_CLK_PERIOD;
    end process;

    -- prescale factor preview value update
    process
    begin
        wait for LHC_CLK_PERIOD;
        prescale_factor_preview <= std_logic_vector(PRESCALE_FACTOR_VALUE_PRVW_UNSGND);
        wait for 1800*LHC_CLK_PERIOD;
    end process;

    -- begin_lumi_per
    process is
    begin
        begin_lumi_per <= '0';
        wait for 35*LHC_CLK_PERIOD;
        begin_lumi_per <= '1';
        wait for LHC_CLK_PERIOD;
        begin_lumi_per <= '0';
        wait for 1000*LHC_CLK_PERIOD;
    end process;


    -- veto_mask, algo_bx_mask, suppress_cal_trigger
    process
    begin
        algo_bx_mask <= '1';
        veto_mask    <= '1';
        suppress_cal_trigger <= '0';
        wait for LHC_CLK_PERIOD;
        algo_bx_mask <= '1';
        veto_mask    <= '1';
        suppress_cal_trigger <= '1';
        wait for 2*LHC_CLK_PERIOD;
        algo_bx_mask <= '1';
        veto_mask    <= '1';
        suppress_cal_trigger <= '0';
        wait;
    end process;



    ------------------- Instantiate  modules  -----------------

    dut: entity work.algo_slice
        generic map(
            RATE_COUNTER_WIDTH    => 32,
            PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
            PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT_VALUE_UNSGND,
            MAX_DELAY             => 63
        )
        port map(
            sys_clk                          => sys_clk,
            lhc_clk                          => lhc_clk,
            lhc_rst                          => lhc_rst,
            sres_algo_rate_counter           => sres_algo_rate_counter,
            sres_algo_pre_scaler             => sres_algo_pre_scaler,
            sres_algo_post_dead_time_counter => sres_algo_post_dead_time_counter,
            suppress_cal_trigger             => suppress_cal_trigger,
            l1a                              => l1a,
            l1a_latency_delay                => "010000",
            request_update_factor_pulse      => request_update_factor_pulse,
            begin_lumi_per                   => begin_lumi_per,
            algo_i                           => algo_i,
            prescale_factor                  => prescale_factor,
            prescale_factor_preview          => prescale_factor_preview,
            algo_bx_mask                     => algo_bx_mask,
            veto_mask                        => veto_mask,
            rate_cnt_before_prescaler        => rate_cnt_before_prescaler,
            rate_cnt_after_prescaler         => rate_cnt_after_prescaler,
            rate_cnt_after_prescaler_preview => rate_cnt_after_prescaler_preview,
            rate_cnt_post_dead_time          => rate_cnt_post_dead_time,
            algo_after_bxomask               => algo_after_bxomask,
            algo_after_prescaler             => algo_after_prescaler,
            algo_after_prescaler_preview     => algo_after_prescaler_preview,
            veto                             => veto
        );

end architecture behav;


