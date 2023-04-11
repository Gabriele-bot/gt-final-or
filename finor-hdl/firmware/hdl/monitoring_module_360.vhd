library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_m_module.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;


--use work.P2GT_monitor_pkg.all;
--use work.pre_scaler_pkg.all;
--use work.Finor_pkg.all;
use work.P2GT_finor_pkg.all;

use work.math_pkg.all;



entity mmonitoring_module_360 is
    generic(
        NR_ALGOS              : natural;
        PRESCALE_FACTOR_INIT  : std_logic_vector(31 DOWNTO 0) := X"00000064"; --1.00
        BEGIN_LUMI_TOGGLE_BIT : natural := 18;
        MAX_DELAY             : natural := 127
    );
    port(
        -- =========================IPbus================================================
        clk                 : in  std_logic;
        rst                 : in  std_logic;
        ipb_in              : in  ipb_wbus;
        ipb_out             : out ipb_rbus;
        -- ==============================================================================
        clk360                   : in  std_logic;
        rst360                   : in  std_logic;

        ctrs                     : in  ttc_stuff_t;

        algos_in                 : in  std_logic_vector(64-1 downto 0);
        valid_algos_in           : in  std_logic;
        algos_after_bxmask_o     : out std_logic_vector(64-1 downto 0);
        algos_after_prescaler_o  : out std_logic_vector(64-1 downto 0);
        trigger_o                : out std_logic_vector(N_TRIGG-1  downto 0);
        trigger_preview_o        : out std_logic_vector(N_TRIGG-1  downto 0);
        valid_trigger_o          : out std_logic;
        veto_o                   : out std_logic

    );
end mmonitoring_module_360;


architecture rtl of mmonitoring_module_360 is

    constant NULL_VETO_MASK    : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '0');

    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

    --algos signal
    signal algos_delayed                 : std_logic_vector(64-1 downto 0) := (others => '0');
    signal algos_after_bxmask            : std_logic_vector(64-1 downto 0) := (others => '0');
    signal algos_after_prescaler         : std_logic_vector(64-1 downto 0) := (others => '0');
    signal algos_after_prescaler_preview : std_logic_vector(64-1 downto 0) := (others => '0');

    -- prescale factor ipb regs
    signal prscl_fct      : ipb_reg_v(NR_ALGOS - 1 downto 0) := (others => PRESCALE_FACTOR_INIT);
    signal prscl_fct_prvw : ipb_reg_v(NR_ALGOS - 1 downto 0) := (others => PRESCALE_FACTOR_INIT);
    
    type prscl_fct_matrix_t is array (64-1 downto 0) of prescale_factor_array(8 downto 0);
    signal prscl_fct_matrix      : prscl_fct_matrix_t := (others => (others => (others => '0')));
    signal prscl_fct_prvw_matrix : prscl_fct_matrix_t := (others => (others => (others => '0')));

    signal rst_prescale_counters           : std_logic;
    signal change_prescale_column_occurred : std_logic;

    -- rate counter ipb regs
    signal rate_cnt_before_prescaler        : ipb_reg_v(NR_ALGOS - 1 downto 0);
    signal rate_cnt_after_prescaler         : ipb_reg_v(NR_ALGOS - 1 downto 0);
    signal rate_cnt_after_prescaler_preview : ipb_reg_v(NR_ALGOS - 1 downto 0);
    signal rate_cnt_post_dead_time          : ipb_reg_v(NR_ALGOS - 1 downto 0);
    
    type rate_cnt_matrix_t is array (64-1 downto 0) of rate_counter_array(8 downto 0);
    signal rate_cnt_bf_pr_matrix       : rate_cnt_matrix_t := (others => (others => (others => '0')));
    signal rate_cnt_af_pr_matrix       : rate_cnt_matrix_t := (others => (others => (others => '0')));
    signal rate_cnt_bf_pr_prvw_matrix  : rate_cnt_matrix_t := (others => (others => (others => '0')));
    signal rate_cnt_pdt_matrix         : rate_cnt_matrix_t := (others => (others => (others => '0')));

    signal masks_ipbus_regs        : ipb_reg_v(NR_ALGOS/32*N_TRIGG - 1 downto 0) := (others => (others => '1'));
    signal masks                   : mask_arr := (others => (others => '1'));

    signal veto_ipbus_regs         : ipb_reg_v(NR_ALGOS/32 - 1 downto 0) := (others => (others => '0'));
    signal veto_mask,veto_mask_int : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '0');

    signal request_factor_update    : std_logic;
    signal new_prescale_column      : std_logic;
    signal request_masks_update     : std_logic;
    signal new_trgg_masks           : std_logic;
    signal request_veto_update      : std_logic;
    signal new_veto                 : std_logic;
    signal ctrl_reg     : ipb_reg_v(1 downto 0) := (others => (others => '0'));
    signal ctrl_reg_stb : ipb_reg_v(1 downto 0) := (others => (others => '0'));
    signal stat_reg     : ipb_reg_v(3 downto 0) := (others => (others => '0'));
    signal ctrl_stb     : std_logic_vector(1 downto 0);

    -- counters and bgos signals
    signal bc0, oc0, ec0               : std_logic := '0';
    signal begin_lumi_per              : std_logic;
    signal begin_lumi_per_del1         : std_logic;
    signal end_lumi_per                : std_logic;
    signal l1a_latency_delay           : std_logic_vector(log2c(MAX_DELAY*9)-1 downto 0);

    signal ctrs_del                    : ttc_stuff_array(1 downto 0);


    type state_t is (idle, start, increment);
    signal state_r, state_w, state_mask           : state_t := idle;

    signal q_prscl_fct, q_prscl_fct_prvw                                 : std_logic_vector(31 downto 0);
    signal q_mask                                                        : std_logic_vector(31 downto 0);
    signal q_veto                                                        : std_logic_vector(31 downto 0);
    signal d_rate_cnt_before_prescaler, d_rate_cnt_after_prescaler       : std_logic_vector(31 downto 0);
    signal d_rate_cnt_after_prescaler_preview, d_rate_cnt_post_dead_time : std_logic_vector(31 downto 0);

    signal addr, addr_prscl         : std_logic_vector(log2c(NR_ALGOS)-1 downto 0);
    signal addr_prscl_w             : std_logic_vector(log2c(NR_ALGOS)-1 downto 0) := (others => '0');
    signal addr_mask                : std_logic_vector(log2c(NR_ALGOS/32*N_TRIGG)-1 downto 0);
    signal addr_mask_w              : std_logic_vector(log2c(NR_ALGOS/32*N_TRIGG)-1 downto 0) := (others => '0');
    signal addr_veto                : std_logic_vector(log2c(NR_ALGOS/32)-1 downto 0);
    signal addr_veto_w              : std_logic_vector(log2c(NR_ALGOS/32)-1 downto 0) := (others => '0');
    signal we, we_mask              : std_logic;
    signal ready                    : std_logic;
    signal ready_mask, ready_mask_1 : std_logic;
    signal ready_veto, ready_veto_1 : std_logic;
    
    --TODO this one can be optimized, instad of 576x4096 use 64x32768
    signal algo_bx_mask_mem_out     : std_logic_vector(NR_ALGOS-1 downto 0) := (others => '1');

    signal orbit_nr                 : eoctr_t;
    signal lumi_sec_nr              : std_logic_vector(31 downto 0);
    signal lumi_sec_load_prscl_mark : std_logic_vector(31 downto 0);
    signal lumi_sec_load_masks_mark : std_logic_vector(31 downto 0);
    signal lumi_sec_load_veto_mark  : std_logic_vector(31 downto 0);
    signal test_en                  : std_logic;
    signal suppress_cal_trigger     : std_logic;
    signal supp_cal_BX_low          : std_logic_vector(11 downto 0);
    signal supp_cal_BX_high         : std_logic_vector(11 downto 0);

    signal veto                     : std_logic_vector(NR_ALGOS-1 downto 0);
    signal veto_out_s               : std_logic;
    signal veto_cnt                 : std_logic_vector(RATE_COUNTER_WIDTH-1 DOWNTO 0);
    signal veto_stat_reg            : ipb_reg_v(0 downto 0);

    signal trigger_out              : std_logic_vector(N_TRIGG-1 downto 0);
    signal trigger_out_preview      : std_logic_vector(N_TRIGG-1 downto 0);
    
    signal frame_ctr                : integer range 0 to 8;
    signal frame_ctr_slv            : std_logic_vector(3 downto 0);

begin


    ----------------------------------------------------------------------------------
    ---------------COUNTERS INTERNAL--------------------------------------------------
    ----------------------------------------------------------------------------------
    --TODO Where to stat counting, need some latency? How much?
    ctrs_del(0) <= ctrs;
    bx_cnt_int_p : process(clk360)
    begin
        if rising_edge(clk360) then
            ctrs_del(ctrs_del'high downto 1) <= ctrs_del(ctrs_del'high-1 downto 0);
        end if;
    end process;
    
    
    ----------------------------------------------------------------------------------
    ---------------FRAME COUNTER------------------------------------------------------
    ----------------------------------------------------------------------------------
    frame_counter_p : process (clk360)
    begin
        if rising_edge(clk360) then -- rising clock edge
            if valid_algos_in = '0' then
                frame_ctr <= 0;
            elsif frame_ctr < 8 then
                frame_ctr <= frame_ctr + 1;
            else
                frame_ctr <= 0;
            end if;
        end if;
    end process frame_counter_p;
    
    frame_ctr_slv <= std_logic_vector(to_unsigned(frame_ctr,4));

    ----------------------------------------------------------------------------------
    ---------------COUNTER MODULE-----------------------------------------------------
    ----------------------------------------------------------------------------------

    Counters_i : entity work.Counter_module
        generic map (
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map (
            clk360         => clk360,
            rst360         => rst360,
            ctrs_in        => ctrs_del(ctrs_del'high),
            bc0            => bc0,
            ec0            => ec0,
            oc0            => oc0,
            bx_nr          => open,
            event_nr       => open,
            orbit_nr       => orbit_nr,
            lumi_sec_nr    => lumi_sec_nr,
            begin_lumi_sec => begin_lumi_per,
            end_lumi_sec   => end_lumi_per,
            test_en        => test_en
        );



    -- TODO check delay

    -- rate counters are updated with begin_lumi_per_del1
    process (clk360)
    begin
        if rising_edge(clk360) then
            begin_lumi_per_del1 <= begin_lumi_per;
        end if;
    end process;

    rate_cntrs_read_FSM_i : entity work.write_FSM
        generic map(
            RAM_DEPTH => NR_ALGOS
        )
        port map(
            clk        => clk360,
            rst        => rst360,
            write_flag => begin_lumi_per_del1,
            addr_o     => addr,
            addr_w_o   => open,
            we_o       => we
        ) ;




    prescaler_read_FSM_i : entity work.read_FSM
        generic map(
            RAM_DEPTH      => NR_ALGOS,
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map(
            clk                => clk360,
            rst                => rst360,
            load_flag          => new_prescale_column,
            orbit_nr           => orbit_nr,
            lumi_sec_nr        => lumi_sec_nr,
            lumi_sec_load_mark => lumi_sec_load_prscl_mark,
            addr_o             => addr_prscl,
            addr_w_o           => addr_prscl_w,
            request_update     => request_factor_update,
            ready_o            => open
        ) ;


    trgg_mask_read_FSM_i : entity work.read_FSM
        generic map(
            RAM_DEPTH      => NR_ALGOS/32*N_TRIGG,
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map(
            clk                => clk360,
            rst                => rst360,
            load_flag          => new_trgg_masks,
            orbit_nr           => orbit_nr,
            lumi_sec_nr        => lumi_sec_nr,
            lumi_sec_load_mark => lumi_sec_load_masks_mark,
            addr_o             => addr_mask,
            addr_w_o           => addr_mask_w,
            request_update     => request_masks_update,
            ready_o            => ready_mask
        ) ;

    process(clk360)
    begin
        if rising_edge(clk360) then
            ready_mask_1 <= ready_mask;
        end if;
    end process;

    veto_read_FSM_i : entity work.read_FSM
        generic map(
            RAM_DEPTH      => NR_ALGOS/32,
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map(
            clk                => clk360,
            rst                => rst360,
            load_flag          => new_veto,
            orbit_nr           => orbit_nr,
            lumi_sec_nr        => lumi_sec_nr,
            lumi_sec_load_mark => lumi_sec_load_veto_mark,
            addr_o             => addr_veto,
            addr_w_o           => addr_veto_w,
            request_update     => request_veto_update,
            ready_o            => ready_veto
        ) ;

    process(clk360)
    begin
        if rising_edge(clk360) then
            ready_veto_1 <= ready_veto;
        end if;
    end process;


    fabric_i: entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_m_module(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    ----------------------------------------------------------------------------------
    ---------------PRE-SCALE REGISTERS------------------------------------------------
    ----------------------------------------------------------------------------------

    prscl_fct_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => PRESCALE_FACTOR_INIT,
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_PRESCALE_FACTOR),
            ipb_out => ipb_from_slaves(N_SLV_PRESCALE_FACTOR),
            rclk    => clk360,
            we      => '0',
            d       => (others => '0'),
            q       => q_prscl_fct,
            addr    => std_logic_vector(addr_prscl)
        );

    ----------------------------------------------------------------------------------
    ---------------PRE-SCALE PREVIEW REGISTERS----------------------------------------
    ----------------------------------------------------------------------------------

    prscl_fct_prvw_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => PRESCALE_FACTOR_INIT,
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_PRESCALE_FACTOR_PRVW),
            ipb_out => ipb_from_slaves(N_SLV_PRESCALE_FACTOR_PRVW),
            rclk    => clk360,
            we      => '0',
            d       => (others => '0'),
            q       => q_prscl_fct_prvw,
            addr    => std_logic_vector(addr_prscl)
        );

    -- process to read from ipbus-RAMs
    process (clk360)
    begin
        if rising_edge(clk360) then
            -----------Prescalers----------------------------
            prscl_fct(to_integer     (unsigned(addr_prscl_w)))  <= q_prscl_fct;
            prscl_fct_prvw(to_integer(unsigned(addr_prscl_w)))  <= q_prscl_fct_prvw;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER BEFORE PRE-SCALE REGISTERS----------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_before_prsc_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_BEFORE_PRSC),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_BEFORE_PRSC),
            rclk    => clk360,
            we      => we,
            d       => d_rate_cnt_before_prescaler,
            q       => open,
            addr    => std_logic_vector(addr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER AFTER PRE-SCALE REGISTERS-----------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_after_prsc_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_AFTER_PRSC),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_AFTER_PRSC),
            rclk    => clk360,
            we      => we,
            d       => d_rate_cnt_after_prescaler,
            q       => open,
            addr    => std_logic_vector(addr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER AFTER PRE-SCALE PREVIEW REGISTERS---------------------
    ----------------------------------------------------------------------------------

    rate_cnt_after_prsc_prvw_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_AFTER_PRSC_PRVW),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_AFTER_PRSC_PRVW),
            rclk    => clk360,
            we      => we,
            d       => d_rate_cnt_after_prescaler_preview,
            q       => open,
            addr    => std_logic_vector(addr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER POST DEAD-TIME REGISTERS------------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_post_dead_time_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_PDT),
            rclk    => clk360,
            we      => we,
            d       => d_rate_cnt_post_dead_time,
            q       => open,
            addr    => std_logic_vector(addr)
        );


    d_rate_cnt_before_prescaler        <= rate_cnt_before_prescaler       (to_integer(unsigned(addr)));
    d_rate_cnt_after_prescaler         <= rate_cnt_after_prescaler        (to_integer(unsigned(addr)));
    d_rate_cnt_after_prescaler_preview <= rate_cnt_after_prescaler_preview(to_integer(unsigned(addr)));
    d_rate_cnt_post_dead_time          <= rate_cnt_post_dead_time         (to_integer(unsigned(addr)));


    CSR_regs : entity work.ipbus_ctrlreg_v
        generic map(
            N_CTRL     => 2,
            N_STAT     => 4
        )
        port map(
            clk       => clk,
            reset     => rst,
            ipbus_in  => ipb_to_slaves(N_SLV_CSR),
            ipbus_out => ipb_from_slaves(N_SLV_CSR),
            d         => stat_reg,
            q         => ctrl_reg,
            qmask     => open,
            stb       => ctrl_stb
        );

    strobe_loop : process(clk)
    begin
        if rising_edge(clk) then
            for i  in 1 downto 0 loop
                if ctrl_stb(i) = '1' then
                    ctrl_reg_stb(i) <= ctrl_reg(i);
                end if;
            end loop;
        end if;
    end process;


    xpm_cdc_new_prescale_column : xpm_cdc_single
        generic map (
            DEST_SYNC_FF => 5,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map (
            dest_out => new_prescale_column,
            dest_clk => clk360,
            src_clk  => clk,
            src_in   => ctrl_reg_stb(0)(0)
        );

    xpm_cdc_new_trgg_masks : xpm_cdc_single
        generic map (
            DEST_SYNC_FF => 5,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map (
            dest_out => new_trgg_masks,
            dest_clk => clk360,
            src_clk  => clk,
            src_in   => ctrl_reg_stb(0)(1)
        );

    xpm_cdc_new_veto : xpm_cdc_single
        generic map (
            DEST_SYNC_FF => 5,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map (
            dest_out => new_veto,
            dest_clk => clk360,
            src_clk  => clk,
            src_in   => ctrl_reg_stb(0)(2)
        );

    xpm_cdc_l1a_latency_delay : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF => 5,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1,
            WIDTH          => log2c(MAX_DELAY*9)
        )
        port map (
            dest_out => l1a_latency_delay,
            dest_clk => clk360,
            src_clk  => clk,
            src_in   => ctrl_reg_stb(0)(log2c(MAX_DELAY*9) + 2 downto 3)
        );

    xpm_cdc_supp_BX_low : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF => 5,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1,
            WIDTH          => 12
        )
        port map (
            dest_out => supp_cal_BX_low,
            dest_clk => clk360,
            src_clk  => clk,
            src_in   => ctrl_reg_stb(1)(11 downto 0)
        );

    xpm_cdc_supp_BX_high : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF => 5,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1,
            WIDTH          => 12
        )
        port map (
            dest_out => supp_cal_BX_high,
            dest_clk => clk360,
            src_clk  => clk,
            src_in   => ctrl_reg_stb(1)(23 downto 12)
        );

    ready <= not we;

    xpm_cdc_ready : xpm_cdc_single
        generic map (
            DEST_SYNC_FF => 5,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG => 1
        )
        port map (
            dest_out => stat_reg(0)(0),
            dest_clk => clk,
            src_clk  => clk360,
            src_in   => ready
        );

    xpm_cdc_prescaler_lumi_mark : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF   => 5,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1,
            WIDTH          => 32
        )
        port map (
            dest_out => stat_reg(1),
            dest_clk => clk,
            src_clk  => clk360,
            src_in   => lumi_sec_load_prscl_mark
        );

    xpm_cdc_masks_lumi_mark : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF   => 5,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1,
            WIDTH          => 32
        )
        port map (
            dest_out => stat_reg(2),
            dest_clk => clk,
            src_clk  => clk360,
            src_in   => lumi_sec_load_masks_mark
        );

    xpm_cdc_veto_lumi_mark : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF   => 5,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1,
            WIDTH          => 32
        )
        port map (
            dest_out => stat_reg(3),
            dest_clk => clk,
            src_clk  => clk360,
            src_in   => lumi_sec_load_veto_mark
        );

    --begin_lumi_per        <= ctrl_reg(0)(0);
    --request_factor_update <= ctrl_reg(0)(1);
    --l1a_latency_delay     <= ctrl_reg(0)(log2c(MAX_DELAY) + 1 downto 2);
    --stat_reg(0)(0)        <= ready;

    ----------------------------------------------------------------------------------
    ---------------RESET PRE-SCALE COUTNER LOGIC--------------------------------------
    ----------------------------------------------------------------------------------

    process (clk360)
    begin
        if rising_edge(clk360) then
            if request_factor_update = '1' then
                change_prescale_column_occurred <= '1';
            elsif begin_lumi_per_del1 = '1' then
                change_prescale_column_occurred <= '0';
            end if;
        end if;
    end process;

    rst_prescale_counters <= begin_lumi_per and change_prescale_column_occurred; -- TODO possibility of glitches, need to investigate


    ----------------------------------------------------------------------------------
    ---------------TRIGGER MASKS REGISTERS--------------------------------------------
    ----------------------------------------------------------------------------------

    masks_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"ffffffff",
            ADDR_WIDTH => log2c(NR_ALGOS/32*N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_TRGG_MASK),
            ipb_out => ipb_from_slaves(N_SLV_TRGG_MASK),
            rclk    => clk360,
            we      => '0',
            d       => (others => '0'),
            q       => q_mask,
            addr    => std_logic_vector(addr_mask)
        );

    process (clk360)
    begin
        if rising_edge(clk360) then
            -----------Trigger masks---------------------------------
            masks_ipbus_regs(to_integer(unsigned(addr_mask_w))) <= q_mask;
        end if;
    end process;

    mask_l : for i in N_TRIGG - 1 downto 0 generate
        process(clk360)
        begin
            if rising_edge(clk360) then
                if (ready_mask = '1' and ready_mask_1 = '0') then --rising edge
                    masks(i) <= (masks_ipbus_regs(i*18+17), masks_ipbus_regs(i*18+16),
                                 masks_ipbus_regs(i*18+15), masks_ipbus_regs(i*18+14),
                                 masks_ipbus_regs(i*18+13), masks_ipbus_regs(i*18+12),
                                 masks_ipbus_regs(i*18+11), masks_ipbus_regs(i*18+10),
                                 masks_ipbus_regs(i*18+9) , masks_ipbus_regs(i*18+8) ,
                                 masks_ipbus_regs(i*18+7) , masks_ipbus_regs(i*18+6) ,
                                 masks_ipbus_regs(i*18+5) , masks_ipbus_regs(i*18+4) ,
                                 masks_ipbus_regs(i*18+3) , masks_ipbus_regs(i*18+2) ,
                                 masks_ipbus_regs(i*18+1) , masks_ipbus_regs(i*18+0) );
                end if;
            end if;
        end process;
    end generate;
    -- TODO Make it interchangable


    ----------------------------------------------------------------------------------
    ------------------VETO MASKS REGISTERS--------------------------------------------
    ----------------------------------------------------------------------------------

    veto_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS/32),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_VETO_MASK),
            ipb_out => ipb_from_slaves(N_SLV_VETO_MASK),
            rclk    => clk360,
            we      => '0',
            d       => (others => '0'),
            q       => q_veto,
            addr    => std_logic_vector(addr_veto)
        );

    process (clk360)
    begin
        if rising_edge(clk360) then
            -----------Veto masks------------------------------------
            veto_ipbus_regs(to_integer(unsigned(addr_veto_w)))  <= q_veto;
        end if;
    end process;

    process(clk360)
    begin
        if rising_edge(clk360) then
            if (ready_veto = '1' and ready_veto_1 = '0') then --rising edge
                veto_mask  <= (veto_ipbus_regs(17), veto_ipbus_regs(16),
                              veto_ipbus_regs(15), veto_ipbus_regs(14),
                              veto_ipbus_regs(13), veto_ipbus_regs(12),
                              veto_ipbus_regs(11), veto_ipbus_regs(10),
                              veto_ipbus_regs(9) , veto_ipbus_regs(8) ,
                              veto_ipbus_regs(7) , veto_ipbus_regs(6) ,
                              veto_ipbus_regs(5) , veto_ipbus_regs(4) ,
                              veto_ipbus_regs(3) , veto_ipbus_regs(2) ,
                              veto_ipbus_regs(1) , veto_ipbus_regs(0) );
            end if;
        end if;
    end process;
    -- TODO Make it interchangable


    veto_update_i: entity work.update_process
        generic map(
            WIDTH      => NR_ALGOS,
            INIT_VALUE => NULL_VETO_MASK
        )
        port map(
            clk                  => clk360,
            request_update_pulse => request_veto_update,
            update_pulse         => end_lumi_per,
            data_i               => veto_mask,
            data_o               => veto_mask_int
        );


    ----------------------------------------------------------------------------------
    ---------------ALGO BX MASK MEM---------------------------------------------------
    ----------------------------------------------------------------------------------

    algo_bx_mask_mem_i : entity work.ipbus_dpram_4096x576
        generic map(
            INIT_VALUE => (others => '1'),
            DATA_WIDTH => NR_ALGOS
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_ALGO_BX_MASKS),
            ipb_out => ipb_from_slaves(N_SLV_ALGO_BX_MASKS),
            rclk    => clk360,
            we      => '0',
            d       => (others => '1'),
            q       => algo_bx_mask_mem_out,
            addr    => ctrs_del(0).bctr -- note that this one is not delayed
        ) ;


    delay_element_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => 64,
            MAX_DELAY  => MAX_DELAY*9
        )
        port map(
            clk    => clk360,
            rst    => rst360,
            data_i => algos_after_prescaler,
            data_o => algos_delayed,
            delay  => l1a_latency_delay
        );

    ----------------------------------------------------------------------------------
    ---------------Suppress Trigger dureing Calibration-------------------------------
    ----------------------------------------------------------------------------------    

    suppress_cal_trigger_p: process (clk360)
    begin
        if rising_edge(clk360) then
            if (test_en = '1' and (unsigned(ctrs_del(0).bctr) >= (unsigned(supp_cal_BX_low)-1)) and (unsigned(ctrs_del(0).bctr) < unsigned(supp_cal_BX_high))) then -- minus 1 to get correct length of gap (see simulation with test_bgo_test_enable_logic_tb.vhd)
                suppress_cal_trigger <= '1'; -- pos. active signal: '1' = suppression of algos caused by calibration trigger during gap !!!
            else
                suppress_cal_trigger <= '0';
            end if;
        end if;
    end process suppress_cal_trigger_p;
    
    ----------------------------------------------------------------------------------
    ---------------------------------Prescale mapping---------------------------------
    ----------------------------------------------------------------------------------
    mapping_factors_l : for i in 0 to 64 - 1 generate
        inner_factor_loop : for j in 0 to 8 generate
            prscl_fct_matrix(i)(j)       <= prscl_fct(i+64*j)(PRESCALE_FACTOR_WIDTH-1 downto 0);
            prscl_fct_prvw_matrix(i)(j)  <= prscl_fct_prvw(i+64*j)(PRESCALE_FACTOR_WIDTH-1 downto 0);
        end generate;
    end generate;       

    ----------------------------------------------------------------------------------
    ---------------------------------Algo Slices--------------------------------------
    ----------------------------------------------------------------------------------
       

    gen_algos_slice_l : for i in 0 to 64 - 1 generate
        algos_slice_i : entity work.algo_slice_360
            generic map(
                EXCLUDE_ALGO_VETOED   => TRUE,
                RATE_COUNTER_WIDTH    => RATE_COUNTER_WIDTH,
                PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
                PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
            )
            port map(
                clk                              => clk360,
                rst                              => rst360,
                sres_algo_rate_counter           => '0',
                sres_algo_pre_scaler             => rst_prescale_counters,
                sres_algo_post_dead_time_counter => '0',
                suppress_cal_trigger             => suppress_cal_trigger,
                l1a                              => ctrs_del(1).l1a, --TODO modify this
                frame_ctr                        => frame_ctr_slv, 
                request_update_factor_pulse      => request_factor_update,
                request_update_veto_pulse        => request_veto_update,
                begin_lumi_per                   => begin_lumi_per,
                end_lumi_per                     => end_lumi_per,
                algo_i                           => algos_in(i),
                algo_del_i                       => algos_delayed(i),
                prescale_factors                 => prscl_fct_matrix(i),
                prescale_factors_preview         => prscl_fct_prvw_matrix(i),
                algo_bx_mask                     => '1',
                veto_mask                        => '0',
                rate_cnt_before_prescaler        => rate_cnt_bf_pr_matrix(i),
                rate_cnt_after_prescaler         => rate_cnt_af_pr_matrix(i),
                rate_cnt_after_prescaler_preview => rate_cnt_bf_pr_prvw_matrix(i),
                rate_cnt_post_dead_time          => rate_cnt_pdt_matrix(i),
                algo_after_bxomask               => algos_after_bxmask(i),
                algo_after_prescaler             => algos_after_prescaler(i),
                algo_after_prescaler_preview     => algos_after_prescaler_preview(i),
                veto                             => veto(i)
            );
    end generate;
    
    ----------------------------------------------------------------------------------
    ---------------------------------Counters mapping---------------------------------
    ----------------------------------------------------------------------------------
    mapping_counters_l : for i in 0 to 64 - 1 generate
        inner_counter_loop : for j in 0 to 8 generate
            rate_cnt_before_prescaler(i+64*j)        <= rate_cnt_bf_pr_matrix(i)(j);
            rate_cnt_after_prescaler(i+64*j)         <= rate_cnt_af_pr_matrix(i)(j);
            rate_cnt_after_prescaler_preview(i+64*j) <= rate_cnt_bf_pr_prvw_matrix(i)(j);
            rate_cnt_post_dead_time(i+64*j)          <= rate_cnt_pdt_matrix(i)(j);
        end generate;
    end generate;

    algos_after_bxmask_o    <= algos_after_bxmask;
    algos_after_prescaler_o <= algos_after_prescaler;

    ----------------------------------------------------------------------------------
    -----------------------Trigger masks and veto-------------------------------------
    ----------------------------------------------------------------------------------   
    --
    --Mask_i : entity work.Mask
    --    generic map(
    --        NR_ALGOS => NR_ALGOS,
    --        OUT_REG  => TRUE
    --    )
    --    port map(
    --        clk                             => clk360,
    --        algos_in                        => algos_after_prescaler,
    --        valid_in                        => valid_algos_in,
    --        masks                           => masks,
    --        request_masks_update_pulse      => request_masks_update,
    --        update_pulse                    => end_lumi_per,
    --        trigger_out                     => trigger_out,
    --        valid_out                       => valid_trigger_o
    --    );
    --
    --Mask_previev_i : entity work.Mask
    --    generic map(
    --        NR_ALGOS => NR_ALGOS,
    --        OUT_REG  => TRUE
    --    )
    --    port map(
    --        clk                             => clk360,
    --        algos_in                        => algos_after_prescaler_preview,
    --        valid_in                        => valid_algos_in,
    --        masks                           => masks,
    --        request_masks_update_pulse      => request_masks_update,
    --        update_pulse                    => end_lumi_per,
    --        trigger_out                     => trigger_out_preview,
    --        valid_out                       => open
    --    );
    --

    ----------------------------------------------------------------------------------
    -----------------------------Veto Rate Counter------------------------------------
    ----------------------------------------------------------------------------------   

    --Veto_rate_counter_i: entity work.algo_rate_counter
    --    generic map(
    --        COUNTER_WIDTH => RATE_COUNTER_WIDTH
    --    )
    --    port map(
    --        sys_clk         => clk,
    --        clk             => clk360,
    --        sres_counter    => '0',
    --        store_cnt_value => begin_lumi_per_del1,
    --        algo_i          => veto_out_s,
    --        counter_o       => veto_cnt
    --    );
    --
    --xpm_cdc_veto_cnt_reg : xpm_cdc_array_single
    --    generic map (
    --        DEST_SYNC_FF   => 5,
    --        INIT_SYNC_FF   => 0,
    --        SIM_ASSERT_CHK => 0,
    --        SRC_INPUT_REG  => 1,
    --        WIDTH          => RATE_COUNTER_WIDTH
    --    )
    --    port map (
    --        dest_out => veto_stat_reg(0)(RATE_COUNTER_WIDTH - 1 downto 0),
    --        dest_clk => clk,
    --        src_clk  => clk360,
    --        src_in   => veto_cnt
    --    );
    --
    --Veto_cnt_regs : entity work.ipbus_ctrlreg_v
    --    generic map(
    --        N_CTRL     => 0,
    --        N_STAT     => 1
    --    )
    --    port map(
    --        clk       => clk,
    --        reset     => rst,
    --        ipbus_in  => ipb_to_slaves(N_SLV_VETO_REG),
    --        ipbus_out => ipb_from_slaves(N_SLV_VETO_REG),
    --        d         => veto_stat_reg,
    --        q         => open,
    --        qmask     => open,
    --        stb       => open
    --    );

    --veto_reg_p : process(clk360)
    --begin
    --    if rising_edge(clk360) then
    --        veto_out_s <= or veto;
    --    end if;
    --end process;

    trigger_o         <= (others => '0');
    trigger_preview_o <= (others => '0');
    veto_o            <= '0';


end rtl;