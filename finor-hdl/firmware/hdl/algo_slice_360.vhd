library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity algo_slice_360 is
    generic(
        EXCLUDE_ALGO_VETOED   : boolean := TRUE;
        RATE_COUNTER_WIDTH    : integer := 32;
        PRESCALE_FACTOR_WIDTH : integer := 24;
        PRESCALE_FACTOR_INIT  : std_logic_vector(31 DOWNTO 0) := X"00000064" --1.00
    );
    port(
        --clocks
        clk : in std_logic;
        rst : in std_logic;

        -- counters synchronous resets 
        sres_algo_rate_counter           : in std_logic;
        sres_algo_pre_scaler             : in std_logic;
        sres_algo_post_dead_time_counter : in std_logic;

        suppress_cal_trigger : in std_logic; -- pos. active signal: '1' = suppression of algos caused by calibration trigger !!!
        l1a                  : in std_logic;
        
        frame_ctr                   : in std_logic_vector(3 downto 0);

        request_update_factor_pulse : in std_logic;
        request_update_veto_pulse   : in std_logic;
        begin_lumi_per              : in std_logic;
        end_lumi_per                : in std_logic;

        algo_i                      : in std_logic;
        algo_del_i                  : in std_logic;

        prescale_factors            : in prescale_factor_array(8 downto 0);
        prescale_factors_preview    : in prescale_factor_array(8 downto 0);

        algo_bx_mask : in std_logic;--TODO add the real logic here
        veto_mask    : in std_logic;

        rate_cnt_before_prescaler        : out rate_counter_array(8 downto 0);
        rate_cnt_after_prescaler         : out rate_counter_array(8 downto 0);
        rate_cnt_after_prescaler_preview : out rate_counter_array(8 downto 0);
        rate_cnt_post_dead_time          : out rate_counter_array(8 downto 0);
        
        algo_after_bxomask           : out std_logic;
        algo_after_prescaler         : out std_logic;
        algo_after_prescaler_preview : out std_logic;

        veto                         : out std_logic
    );
end algo_slice_360;

architecture rtl of algo_slice_360 is

    signal algo_after_algo_bx_mask_int0     : std_logic;
    signal algo_after_algo_bx_mask_int1     : std_logic;
    signal algo_after_prescaler_int         : std_logic;
    signal algo_after_prescaler_preview_int : std_logic;
    signal begin_lumi_per_del1              : std_logic;
    signal veto_vec                         : std_logic_vector(0  downto 0);
    signal veto_int                         : std_logic_vector(0  downto 0);
    
    signal frame_ctr_int0, frame_ctr_int1 : std_logic_vector(3 downto 0);


begin

    begin_lumi_per_del_p: process(clk)
    begin
        if rising_edge(clk) then
            begin_lumi_per_del1 <= begin_lumi_per;
        end if;
    end process;
    
    process (clk)
    begin
        if rising_edge(clk) then
            algo_after_algo_bx_mask_int0 <= algo_i and algo_bx_mask and not suppress_cal_trigger;
            algo_after_algo_bx_mask_int1 <= algo_after_algo_bx_mask_int0;
            
            frame_ctr_int0  <= frame_ctr;
            frame_ctr_int1  <= frame_ctr_int0;
        end if;
    end process;

    rate_cnt_before_prescaler_i: entity work.algo_rate_counter_360
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk             => clk,
            sres_counter    => sres_algo_rate_counter,
            store_cnt_value => begin_lumi_per,
            --store_cnt_value => begin_lumi_per_del1,
            algo_i          => algo_after_algo_bx_mask_int1,
            frame_ctr       => frame_ctr_int1,
            counter_o       => rate_cnt_before_prescaler
        );

    prescaler_i: entity work.algo_pre_scaler_360
        generic map(
            PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
            PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
        )
        port map(
            clk                         => clk,
            sres_counter                => sres_algo_pre_scaler,
            algo_i                      => algo_after_algo_bx_mask_int0,
            request_update_factor_pulse => request_update_factor_pulse,
            update_factor_pulse         => end_lumi_per,
            prescale_factors            => prescale_factors,
            frame_ctr                   => frame_ctr_int0,
            prescaled_algo_o            => algo_after_prescaler_int
        );

    rate_cnt_after_prescaler_i: entity work.algo_rate_counter_360
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk             => clk,
            sres_counter    => sres_algo_rate_counter,
            store_cnt_value => begin_lumi_per,
            --store_cnt_value => begin_lumi_per_del1,
            algo_i          => algo_after_prescaler_int,
            frame_ctr       => frame_ctr_int1,
            counter_o       => rate_cnt_after_prescaler
        );


    prescaler_preview_i: entity work.algo_pre_scaler_360
        generic map(
            PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
            PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
        )
        port map(
            clk                         => clk,
            sres_counter                => sres_algo_pre_scaler,
            algo_i                      => algo_after_algo_bx_mask_int0,
            request_update_factor_pulse => request_update_factor_pulse,
            update_factor_pulse         => end_lumi_per,
            prescale_factors            => prescale_factors_preview,
            frame_ctr                   => frame_ctr_int0,
            prescaled_algo_o            => algo_after_prescaler_preview_int
        );

    veto <= algo_after_prescaler_int and veto_mask;

    rate_cnt_after_prescaler_preview_i: entity work.algo_rate_counter_360
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk             => clk,
            sres_counter    => sres_algo_rate_counter,
            store_cnt_value => begin_lumi_per,
            --store_cnt_value => begin_lumi_per_del1,
            algo_i          => algo_after_prescaler_preview_int,
            frame_ctr       => frame_ctr_int1,
            counter_o       => rate_cnt_after_prescaler_preview
        );


    
    --TODO change source of post dead time (after prescaler)
    rate_cnt_post_dead_time_i: entity work.algo_rate_counter_pdt_360
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk             => clk,
            sres_counter    => sres_algo_post_dead_time_counter,
            store_cnt_value => begin_lumi_per,
            --store_cnt_value => begin_lumi_per_del1,
            algo_del_i      => algo_del_i,
            frame_ctr       => frame_ctr_int1, --TODO delay this one!
            l1a             => l1a,
            counter_o       => rate_cnt_post_dead_time
        );


    -- ****************************************************************************************************
    
    
    veto_exclusion: if EXCLUDE_ALGO_VETOED generate
        algo_after_bxomask           <= algo_after_algo_bx_mask_int1     and not veto_mask;
        algo_after_prescaler         <= algo_after_prescaler_int         and not veto_mask;
        algo_after_prescaler_preview <= algo_after_prescaler_preview_int and not veto_mask;
    else generate
        algo_after_bxomask           <= algo_after_algo_bx_mask_int1;
        algo_after_prescaler         <= algo_after_prescaler_int;
        algo_after_prescaler_preview <= algo_after_prescaler_preview_int;
    end generate;

end architecture rtl;