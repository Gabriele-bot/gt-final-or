-- Description:
-- Prescale and rate monitoring structure for one algo (slice) for the P2GT FinalOR board
-- algo-bx-mask at algo input

-- Created by Gabriele Bortolato 14-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware) 

-- Resources utilization
-- |       | Synth |  Impl |
-- |-------|-------|-------|
-- | Carry |       |       |
-- | LUT   |  335  |  336  |
-- | FF    |  412  |  412  |

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity algo_slice is
    generic(
        EXCLUDE_ALGO_VETOED   : boolean                       := TRUE;
        RATE_COUNTER_WIDTH    : integer                       := 32;
        PRESCALE_FACTOR_WIDTH : integer                       := 24;
        PRESCALE_FACTOR_INIT  : std_logic_vector(31 DOWNTO 0) := X"00000064" --1.00
    );
    port(
        --clocks
        clk40                               : in  std_logic;
        rst40                               : in  std_logic;
        -- counters synchronous resets 
        sres_algo_rate_counter              : in  std_logic;
        sres_algo_pre_scaler                : in  std_logic;
        sres_algo_pre_scaler_preview        : in  std_logic;
        sres_algo_post_dead_time_counter    : in  std_logic;
        suppress_cal_trigger                : in  std_logic; -- pos. active signal: '1' = suppression of algos caused by calibration trigger !!!
        l1a                                 : in  std_logic;
        request_update_factor_pulse         : in  std_logic;
        request_update_factor_preview_pulse : in  std_logic;
        begin_lumi_per                      : in  std_logic;
        end_lumi_per                        : in  std_logic;
        algo_i                              : in  std_logic;
        algo_after_prscl_del_i              : in  std_logic;
        prescale_factor                     : in  std_logic_vector(PRESCALE_FACTOR_WIDTH - 1 DOWNTO 0);
        prescale_factor_preview             : in  std_logic_vector(PRESCALE_FACTOR_WIDTH - 1 DOWNTO 0);
        algo_bx_mask                        : in  std_logic;
        veto_mask                           : in  std_logic;
        rate_cnt_before_prescaler           : out std_logic_vector(RATE_COUNTER_WIDTH - 1 DOWNTO 0);
        rate_cnt_after_prescaler            : out std_logic_vector(RATE_COUNTER_WIDTH - 1 DOWNTO 0);
        rate_cnt_after_prescaler_preview    : out std_logic_vector(RATE_COUNTER_WIDTH - 1 DOWNTO 0);
        rate_cnt_post_dead_time             : out std_logic_vector(RATE_COUNTER_WIDTH - 1 DOWNTO 0);
        algo_after_bxomask                  : out std_logic;
        algo_after_prescaler                : out std_logic;
        algo_after_prescaler_preview        : out std_logic;
        veto                                : out std_logic
    );
end algo_slice;

architecture rtl of algo_slice is

    signal algo_after_algo_bx_mask_int      : std_logic;
    signal algo_after_prescaler_int         : std_logic;
    signal algo_after_prescaler_preview_int : std_logic;
    signal begin_lumi_per_del1              : std_logic;

begin

    begin_lumi_per_del_p : process(clk40)
    begin
        if rising_edge(clk40) then
            begin_lumi_per_del1 <= begin_lumi_per;
        end if;
    end process;

    algo_after_algo_bx_mask_int <= algo_i and algo_bx_mask and not suppress_cal_trigger;

    rate_cnt_before_prescaler_i : entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk40           => clk40,
            rst40           => rst40,
            sres_counter    => sres_algo_rate_counter,
            store_cnt_value => begin_lumi_per,
            --store_cnt_value => begin_lumi_per_del1,
            algo_i          => algo_after_algo_bx_mask_int,
            counter_o       => rate_cnt_before_prescaler
        );

    prescaler_i : entity work.algo_pre_scaler
        generic map(
            PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
            PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
        )
        port map(
            clk40                       => clk40,
            rst40                       => rst40,
            sres_counter                => sres_algo_pre_scaler,
            algo_i                      => algo_after_algo_bx_mask_int,
            request_update_factor_pulse => request_update_factor_pulse,
            update_factor_pulse         => end_lumi_per,
            prescale_factor             => prescale_factor,
            prescaled_algo_o            => algo_after_prescaler_int
        );

    rate_cnt_after_prescaler_i : entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk40           => clk40,
            rst40           => rst40,
            sres_counter    => sres_algo_rate_counter,
            store_cnt_value => begin_lumi_per,
            --store_cnt_value => begin_lumi_per_del1,
            algo_i          => algo_after_prescaler_int,
            counter_o       => rate_cnt_after_prescaler
        );

    prescaler_preview_i : entity work.algo_pre_scaler
        generic map(
            PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
            PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
        )
        port map(
            clk40                       => clk40,
            rst40                       => rst40,
            sres_counter                => sres_algo_pre_scaler_preview,
            algo_i                      => algo_after_algo_bx_mask_int,
            request_update_factor_pulse => request_update_factor_preview_pulse,
            update_factor_pulse         => end_lumi_per,
            prescale_factor             => prescale_factor_preview,
            prescaled_algo_o            => algo_after_prescaler_preview_int
        );

    veto <= algo_after_prescaler_int and veto_mask;

    rate_cnt_after_prescaler_preview_i : entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk40           => clk40,
            rst40           => rst40,
            sres_counter    => sres_algo_rate_counter,
            store_cnt_value => begin_lumi_per,
            --store_cnt_value => begin_lumi_per_del1,
            algo_i          => algo_after_prescaler_preview_int,
            counter_o       => rate_cnt_after_prescaler_preview
        );

    rate_cnt_post_dead_time_i : entity work.algo_rate_counter_pdt
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk40           => clk40,
            rst40           => rst40,
            sres_counter    => sres_algo_post_dead_time_counter,
            store_cnt_value => begin_lumi_per,
            --store_cnt_value => begin_lumi_per_del1,
            l1a             => l1a,
            algo_del_i      => algo_after_prscl_del_i,
            counter_o       => rate_cnt_post_dead_time
        );

    -- ****************************************************************************************************

    --TODO maybe add algos with and w/o veto
    veto_exclusion : if EXCLUDE_ALGO_VETOED generate
        algo_after_bxomask           <= algo_after_algo_bx_mask_int and not veto_mask;
        algo_after_prescaler         <= algo_after_prescaler_int and not veto_mask;
        algo_after_prescaler_preview <= algo_after_prescaler_preview_int and not veto_mask;
    else generate
        algo_after_bxomask           <= algo_after_algo_bx_mask_int;
        algo_after_prescaler         <= algo_after_prescaler_int;
        algo_after_prescaler_preview <= algo_after_prescaler_preview_int;
    end generate;

end architecture rtl;

