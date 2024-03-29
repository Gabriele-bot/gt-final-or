library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_monitoring_module.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity monitoring_module is
    generic(
        NR_ALGOS              : natural;
        NR_TRIGGERS           : natural;
        PRESCALE_FACTOR_INIT  : std_logic_vector(31 DOWNTO 0) := X"00000064"; --1.00
        BEGIN_LUMI_TOGGLE_BIT : natural                       := 18;
        MAX_DELAY             : natural                       := 255;
        SIM                   : boolean                       := FALSE
    );
    port(
        -- =========================IPBus================================================
        clk                     : in  std_logic;
        rst                     : in  std_logic;
        ipb_in                  : in  ipb_wbus;
        ipb_out                 : out ipb_rbus;
        -- ==============================================================================
        clk360                  : in  std_logic;
        rst360                  : in  std_logic;
        clk40                   : in  std_logic;
        rst40                   : in  std_logic;
        ctrs                    : in  ttc_stuff_t;
        algos_in                : in  std_logic_vector(NR_ALGOS - 1 downto 0);
        valid_algos_in          : in  std_logic;
        algos_after_bxmask_o    : out std_logic_vector(NR_ALGOS - 1 downto 0);
        algos_after_prescaler_o : out std_logic_vector(NR_ALGOS - 1 downto 0);
        trigger_o               : out std_logic_vector(NR_TRIGGERS - 1 downto 0);
        trigger_preview_o       : out std_logic_vector(NR_TRIGGERS - 1 downto 0);
        valid_trigger_o         : out std_logic;
        veto_o                  : out std_logic;
        start_of_orbit_o        : out std_logic;
        resync_o                : out std_logic
    );
end monitoring_module;

architecture rtl of monitoring_module is

    constant NULL_VETO_MASK : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '0');
    constant N_CTRL         : natural                                 := 2;
    constant N_STAT         : natural                                 := 5;

    -- fabric signals        
    signal ipb_to_slaves   : ipb_wbus_array(N_SLAVES - 1 downto 0);
    signal ipb_from_slaves : ipb_rbus_array(N_SLAVES - 1 downto 0);

    --algos signal
    signal algos_delayed                 : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '0');
    signal algos_after_bxmask            : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '0');
    signal algos_after_prescaler         : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '0');
    signal algos_after_prescaler_preview : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '0');

    signal algos_delayed_with_valid : std_logic_vector(NR_ALGOS downto 0) := (others => '0');
    signal valid_algos_delayed      : std_logic;

    -- prescale factor ipb regs
    signal prscl_fct      : ipb_reg_v(N_SLR_ALGOS_MAX - 1 downto 0) := (others => PRESCALE_FACTOR_INIT);
    signal prscl_fct_prvw : ipb_reg_v(N_SLR_ALGOS_MAX - 1 downto 0) := (others => PRESCALE_FACTOR_INIT);

    signal rst_prescale_counters                   : std_logic;
    signal rst_prescale_preview_counters           : std_logic;
    signal change_prescale_column_occurred         : std_logic;
    signal change_prescale_preview_column_occurred : std_logic;

    -- rate counter ipb regs
    signal rate_cnt_before_prescaler        : ipb_reg_v(N_SLR_ALGOS_MAX - 1 downto 0);
    signal rate_cnt_after_prescaler         : ipb_reg_v(N_SLR_ALGOS_MAX - 1 downto 0);
    signal rate_cnt_after_prescaler_preview : ipb_reg_v(N_SLR_ALGOS_MAX - 1 downto 0);
    signal rate_cnt_post_dead_time          : ipb_reg_v(N_SLR_ALGOS_MAX - 1 downto 0);

    signal masks_ipbus_regs : ipb_reg_v(N_SLR_ALGOS_MAX / 32 * NR_TRIGGERS - 1 downto 0) := (others => (others => '1'));
    signal masks            : mask_arr                                                   := (others => (others => '1'));

    signal veto_ipbus_regs : ipb_reg_v(N_SLR_ALGOS_MAX / 32 - 1 downto 0)   := (others => (others => '0'));
    signal veto_mask       : std_logic_vector(N_SLR_ALGOS_MAX - 1 downto 0) := (others => '0');
    signal veto_mask_int   : std_logic_vector(NR_ALGOS - 1 downto 0)        := (others => '0');

    signal request_factor_update         : std_logic;
    signal request_factor_preview_update : std_logic;
    signal new_prescale_column           : std_logic;
    signal new_prescale_preview_column   : std_logic;
    signal request_masks_update          : std_logic;
    signal new_trgg_masks                : std_logic;
    signal request_veto_update           : std_logic;
    signal new_veto                      : std_logic;
    signal ctrl_reg                      : ipb_reg_v(N_CTRL - 1 downto 0) := (others => (others => '0'));
    signal ctrl_reg_stb                  : ipb_reg_v(N_CTRL - 1 downto 0) := (others => (others => '0'));
    signal stat_reg                      : ipb_reg_v(N_STAT - 1 downto 0) := (others => (others => '0'));
    signal ctrl_stb                      : std_logic_vector(N_CTRL - 1 downto 0);

    -- counters and bgos signals
    signal ttc_bc0, ttc_oc0, ttc_ec0 : std_logic := '0';
    signal ttc_resync, ttc_start     : std_logic;
    signal ttc_test_en               : std_logic;
    signal bc0_reg, oc0_reg, ec0_reg : std_logic := '0';
    signal bc0_40, oc0_40, ec0_40    : std_logic := '0';
    signal resync_reg, start_reg     : std_logic;
    signal resync_40, start_40       : std_logic;
    signal begin_lumi_per            : std_logic;
    signal begin_lumi_per_del1       : std_logic;
    signal end_lumi_per              : std_logic;
    signal l1a_latency_delay         : std_logic_vector(log2c(MAX_DELAY) - 1 downto 0);

    signal ctrs_reg      : ttc_stuff_t;
    signal ctrs_internal : ttc_stuff_t;

    type state_t is (idle, start, increment);
    signal state_r, state_w, state_mask : state_t := idle;

    signal q_prscl_fct, q_prscl_fct_prvw                                 : std_logic_vector(31 downto 0);
    signal q_mask                                                        : std_logic_vector(31 downto 0);
    signal q_veto                                                        : std_logic_vector(31 downto 0);
    signal d_rate_cnt_before_prescaler, d_rate_cnt_after_prescaler       : std_logic_vector(31 downto 0);
    signal d_rate_cnt_after_prescaler_preview, d_rate_cnt_post_dead_time : std_logic_vector(31 downto 0);

    signal addr_rate_cntr           : std_logic_vector(log2c(N_SLR_ALGOS_MAX) - 1 downto 0);
    signal addr_prscl               : std_logic_vector(log2c(N_SLR_ALGOS_MAX) - 1 downto 0);
    signal addr_prscl_w             : std_logic_vector(log2c(N_SLR_ALGOS_MAX) - 1 downto 0)                    := (others => '0');
    signal addr_prscl_prvw          : std_logic_vector(log2c(N_SLR_ALGOS_MAX) - 1 downto 0);
    signal addr_prscl_prvw_w        : std_logic_vector(log2c(N_SLR_ALGOS_MAX) - 1 downto 0)                    := (others => '0');
    signal addr_mask                : std_logic_vector(log2c(N_SLR_ALGOS_MAX / 32 * NR_TRIGGERS) - 1 downto 0);
    signal addr_mask_w              : std_logic_vector(log2c(N_SLR_ALGOS_MAX / 32 * NR_TRIGGERS) - 1 downto 0) := (others => '0');
    signal addr_veto                : std_logic_vector(log2c(N_SLR_ALGOS_MAX / 32) - 1 downto 0);
    signal addr_veto_w              : std_logic_vector(log2c(N_SLR_ALGOS_MAX / 32) - 1 downto 0)               := (others => '0');
    signal we, we_mask              : std_logic;
    signal ready                    : std_logic;
    signal ready_mask, ready_mask_1 : std_logic;
    signal ready_veto, ready_veto_1 : std_logic;

    signal algo_bx_mask_mem_out : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '1');

    signal orbit_nr                      : std_logic_vector(47 downto 0);
    signal lumi_sec_nr                   : std_logic_vector(31 downto 0);
    signal lumi_sec_load_prscl_mark      : std_logic_vector(31 downto 0);
    signal lumi_sec_load_prscl_prvw_mark : std_logic_vector(31 downto 0);
    signal lumi_sec_load_masks_mark      : std_logic_vector(31 downto 0);
    signal lumi_sec_load_veto_mark       : std_logic_vector(31 downto 0);
    signal test_en                       : std_logic;
    signal suppress_cal_trigger          : std_logic;
    signal supp_cal_BX_low               : std_logic_vector(11 downto 0);
    signal supp_cal_BX_high              : std_logic_vector(11 downto 0);

    signal veto          : std_logic_vector(NR_ALGOS - 1 downto 0);
    signal veto_out_s    : std_logic;
    signal veto_cnt      : std_logic_vector(RATE_COUNTER_WIDTH - 1 DOWNTO 0);
    signal veto_stat_reg : ipb_reg_v(0 downto 0);

    signal trigger_out         : std_logic_vector(NR_TRIGGERS - 1 downto 0);
    signal trigger_out_preview : std_logic_vector(NR_TRIGGERS - 1 downto 0);
    signal BX_nr_trigger       : p2gt_bctr_t;

begin

    ----------------------------------------------------------------------------------
    ---------------BGOs SYNC----------------------------------------------------------
    ----------------------------------------------------------------------------------
    BGOs_sync_i : entity work.bgo_sync
        port map(
            clk360            => clk360,
            rst360            => rst360,
            ttc_i             => ctrs.ttc_cmd,
            bc0_o             => ttc_bc0,
            ec0_o             => open,
            ec0_sync_bc0_o    => ttc_ec0,
            oc0_o             => open,
            oc0_sync_bc0_o    => ttc_oc0,
            resync_o          => resync_o,
            resync_sync_bc0_o => ttc_resync,
            start_o           => open,
            start_sync_bc0_o  => ttc_start,
            test_en_o         => ttc_test_en
        );

    deser_reg_out_g : if DESER_OUT_REG generate
        process(clk40)
        begin
            if rising_edge(clk40) then
                ctrs_reg   <= ctrs;
                bc0_reg    <= ttc_bc0;
                oc0_reg    <= ttc_oc0;
                ec0_reg    <= ttc_ec0;
                start_reg  <= ttc_start;
                resync_reg <= ttc_resync;
            end if;
        end process;
    else generate
        ctrs_reg   <= ctrs;
        bc0_reg    <= ttc_bc0;
        oc0_reg    <= ttc_oc0;
        ec0_reg    <= ttc_ec0;
        start_reg  <= ttc_start;
        resync_reg <= ttc_resync;
    end generate;

    ----------------------------------------------------------------------------------
    ---------------TTC signal sync 40-------------------------------------------------
    ----------------------------------------------------------------------------------
    sync_ctrs_p : process(clk40)
    begin
        if rising_edge(clk40) then
            ctrs_internal <= ctrs_reg;
            bc0_40        <= bc0_reg;
            oc0_40        <= oc0_reg;
            ec0_40        <= ec0_reg;
            start_40      <= start_reg;
            resync_40     <= resync_reg;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    ---------------COUNTER MODULE-----------------------------------------------------
    ----------------------------------------------------------------------------------

    Counters_i : entity work.Counter_module
        generic map(
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map(
            clk40          => clk40,
            rst40          => rst40,
            bc0_i          => bc0_40,
            ec0_i          => ec0_40,
            oc0_i          => oc0_40,
            test_en_i      => ttc_test_en,
            l1a_i          => ctrs_internal.l1a,
            bx_nr_i        => ctrs_internal.bctr,
            bx_nr_o        => open,
            event_nr_o     => open,
            orbit_nr_o     => orbit_nr,
            lumi_sec_nr    => lumi_sec_nr,
            begin_lumi_sec => begin_lumi_per,
            end_lumi_sec   => end_lumi_per,
            test_en_o      => test_en
        );

    -- rate counter registers update starts with begin_lumi_per_del1
    process(clk40)
    begin
        if rising_edge(clk40) then
            begin_lumi_per_del1 <= begin_lumi_per;
        end if;
    end process;

    rate_cntrs_read_FSM_i : entity work.write_FSM
        generic map(
            RAM_DEPTH => N_SLR_ALGOS_MAX
        )
        port map(
            clk        => clk40,
            rst        => rst40,
            write_flag => begin_lumi_per_del1,
            addr_o     => addr_rate_cntr,
            addr_w_o   => open,
            we_o       => we
        );

    prescaler_read_FSM_i : entity work.read_FSM
        generic map(
            RAM_DEPTH      => N_SLR_ALGOS_MAX,
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map(
            clk                => clk40,
            rst                => rst40,
            load_flag          => new_prescale_column,
            orbit_nr           => orbit_nr,
            lumi_sec_nr        => lumi_sec_nr,
            lumi_sec_load_mark => lumi_sec_load_prscl_mark,
            addr_o             => addr_prscl,
            addr_w_o           => addr_prscl_w,
            request_update     => request_factor_update,
            ready_o            => open
        );

    prescaler_preview_read_FSM_i : entity work.read_FSM
        generic map(
            RAM_DEPTH      => N_SLR_ALGOS_MAX,
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map(
            clk                => clk40,
            rst                => rst40,
            load_flag          => new_prescale_preview_column,
            orbit_nr           => orbit_nr,
            lumi_sec_nr        => lumi_sec_nr,
            lumi_sec_load_mark => lumi_sec_load_prscl_prvw_mark,
            addr_o             => addr_prscl_prvw,
            addr_w_o           => addr_prscl_prvw_w,
            request_update     => request_factor_preview_update,
            ready_o            => open
        );

    trgg_mask_read_FSM_i : entity work.read_FSM
        generic map(
            RAM_DEPTH      => N_SLR_ALGOS_MAX / 32 * NR_TRIGGERS,
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map(
            clk                => clk40,
            rst                => rst40,
            load_flag          => new_trgg_masks,
            orbit_nr           => orbit_nr,
            lumi_sec_nr        => lumi_sec_nr,
            lumi_sec_load_mark => lumi_sec_load_masks_mark,
            addr_o             => addr_mask,
            addr_w_o           => addr_mask_w,
            request_update     => request_masks_update,
            ready_o            => ready_mask
        );

    process(clk40)
    begin
        if rising_edge(clk40) then
            ready_mask_1 <= ready_mask;
        end if;
    end process;

    veto_read_FSM_i : entity work.read_FSM
        generic map(
            RAM_DEPTH      => N_SLR_ALGOS_MAX / 32,
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map(
            clk                => clk40,
            rst                => rst40,
            load_flag          => new_veto,
            orbit_nr           => orbit_nr,
            lumi_sec_nr        => lumi_sec_nr,
            lumi_sec_load_mark => lumi_sec_load_veto_mark,
            addr_o             => addr_veto,
            addr_w_o           => addr_veto_w,
            request_update     => request_veto_update,
            ready_o            => ready_veto
        );

    process(clk40)
    begin
        if rising_edge(clk40) then
            ready_veto_1 <= ready_veto;
        end if;
    end process;

    fabric_i : entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_monitoring_module(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    ----------------------------------------------------------------------------------
    ---------------PRE-SCALE REGISTERS------------------------------------------------
    ----------------------------------------------------------------------------------

    prscl_fct_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => PRESCALE_FACTOR_INIT,
            ADDR_WIDTH => log2c(N_SLR_ALGOS_MAX),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_PRESCALE_FACTOR),
            ipb_out => ipb_from_slaves(N_SLV_PRESCALE_FACTOR),
            rclk    => clk40,
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
            ADDR_WIDTH => log2c(N_SLR_ALGOS_MAX),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_PRESCALE_FACTOR_PRVW),
            ipb_out => ipb_from_slaves(N_SLV_PRESCALE_FACTOR_PRVW),
            rclk    => clk40,
            we      => '0',
            d       => (others => '0'),
            q       => q_prscl_fct_prvw,
            addr    => std_logic_vector(addr_prscl_prvw)
        );

    -- process to read from ipbus-RAMs
    process(clk40)
    begin
        if rising_edge(clk40) then
            -----------Prescalers----------------------------
            prscl_fct(to_integer(unsigned(addr_prscl_w)))           <= q_prscl_fct;
            prscl_fct_prvw(to_integer(unsigned(addr_prscl_prvw_w))) <= q_prscl_fct_prvw;
        end if;
    end process;

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER BEFORE PRE-SCALE REGISTERS----------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_before_prsc_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_SLR_ALGOS_MAX),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_BEFORE_PRSC),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_BEFORE_PRSC),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_before_prescaler,
            q       => open,
            addr    => std_logic_vector(addr_rate_cntr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER AFTER PRE-SCALE REGISTERS-----------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_after_prsc_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_SLR_ALGOS_MAX),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_AFTER_PRSC),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_AFTER_PRSC),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_after_prescaler,
            q       => open,
            addr    => std_logic_vector(addr_rate_cntr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER AFTER PRE-SCALE PREVIEW REGISTERS---------------------
    ----------------------------------------------------------------------------------

    rate_cnt_after_prsc_prvw_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_SLR_ALGOS_MAX),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_AFTER_PRSC_PRVW),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_AFTER_PRSC_PRVW),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_after_prescaler_preview,
            q       => open,
            addr    => std_logic_vector(addr_rate_cntr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER POST DEAD-TIME REGISTERS------------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_post_dead_time_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_SLR_ALGOS_MAX),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_post_dead_time,
            q       => open,
            addr    => std_logic_vector(addr_rate_cntr)
        );

    d_rate_cnt_before_prescaler        <= rate_cnt_before_prescaler(to_integer(unsigned(addr_rate_cntr)));
    d_rate_cnt_after_prescaler         <= rate_cnt_after_prescaler(to_integer(unsigned(addr_rate_cntr)));
    d_rate_cnt_after_prescaler_preview <= rate_cnt_after_prescaler_preview(to_integer(unsigned(addr_rate_cntr)));
    d_rate_cnt_post_dead_time          <= rate_cnt_post_dead_time(to_integer(unsigned(addr_rate_cntr)));

    CSR_regs : entity work.ipbus_ctrlreg_cdc_v
        generic map(
            N_CTRL         => N_CTRL,
            N_STAT         => N_STAT,
            DEST_SYNC_FF   => 3,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CSR),
            ipb_out => ipb_from_slaves(N_SLV_CSR),
            slv_clk => clk40,
            d       => stat_reg,
            q       => ctrl_reg,
            qmask   => open,
            stb     => ctrl_stb
        );

    strobe_loop : process(clk40)
    begin
        if rising_edge(clk40) then
            for i in N_CTRL - 1 downto 0 loop
                if ctrl_stb(i) = '1' then
                    ctrl_reg_stb(i) <= ctrl_reg(i);
                end if;
            end loop;
        end if;
    end process;

    new_prescale_column         <= ctrl_reg(0)(0) and ctrl_stb(0);
    new_prescale_preview_column <= ctrl_reg(0)(1) and ctrl_stb(0);
    new_trgg_masks              <= ctrl_reg(0)(2) and ctrl_stb(0);
    new_veto                    <= ctrl_reg(0)(3) and ctrl_stb(0);
    l1a_latency_delay           <= ctrl_reg_stb(0)(log2c(MAX_DELAY) + 3 downto 4);
    supp_cal_BX_low             <= ctrl_reg_stb(1)(11 downto 0);
    supp_cal_BX_high            <= ctrl_reg_stb(1)(23 downto 12);

    ready <= not we;

    stat_reg(0)(0)           <= ready;
    stat_reg(0)(31 downto 1) <= (others => '0');
    stat_reg(1)              <= lumi_sec_load_prscl_mark;
    stat_reg(2)              <= lumi_sec_load_prscl_prvw_mark;
    stat_reg(3)              <= lumi_sec_load_masks_mark;
    stat_reg(4)              <= lumi_sec_load_veto_mark;

    ----------------------------------------------------------------------------------
    ---------------RESET PRE-SCALE COUNTER LOGIC--------------------------------------
    ----------------------------------------------------------------------------------

    process(clk40)
    begin
        if rising_edge(clk40) then
            if request_factor_update = '1' then
                change_prescale_column_occurred <= '1';
            elsif begin_lumi_per_del1 = '1' then
                change_prescale_column_occurred <= '0';
            end if;
            if request_factor_preview_update = '1' then
                change_prescale_preview_column_occurred <= '1';
            elsif begin_lumi_per_del1 = '1' then
                change_prescale_preview_column_occurred <= '0';
            end if;
        end if;
    end process;

    rst_prescale_counters         <= begin_lumi_per and change_prescale_column_occurred; -- TODO possibility of glitches, need to investigate
    rst_prescale_preview_counters <= begin_lumi_per and change_prescale_preview_column_occurred; -- TODO possibility of glitches, need to investigate

    ----------------------------------------------------------------------------------
    ---------------TRIGGER MASKS REGISTERS--------------------------------------------
    ----------------------------------------------------------------------------------

    masks_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"ffffffff",
            ADDR_WIDTH => log2c(N_SLR_ALGOS_MAX / 32 * NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_TRGG_MASK),
            ipb_out => ipb_from_slaves(N_SLV_TRGG_MASK),
            rclk    => clk40,
            we      => '0',
            d       => (others => '0'),
            q       => q_mask,
            addr    => std_logic_vector(addr_mask)
        );

    process(clk40)
    begin
        if rising_edge(clk40) then
            -----------Trigger masks---------------------------------
            masks_ipbus_regs(to_integer(unsigned(addr_mask_w))) <= q_mask;
        end if;
    end process;

    mask_out_l : for i in NR_TRIGGERS - 1 downto 0 generate
        mask_in_l : for j in N_SLR_ALGOS_MAX / 32 - 1 downto 0 generate
            process(clk40)
            begin
                if rising_edge(clk40) then
                    if (ready_mask = '1' and ready_mask_1 = '0') then --rising edge
                        masks(i)((j + 1) * 32 - 1 downto j * 32) <= masks_ipbus_regs(i * (N_SLR_ALGOS_MAX / 32) + j);
                        --masks(i) <= (masks_ipbus_regs(i * 18 + 17), masks_ipbus_regs(i * 18 + 16),
                        --             masks_ipbus_regs(i * 18 + 15), masks_ipbus_regs(i * 18 + 14),
                        --             masks_ipbus_regs(i * 18 + 13), masks_ipbus_regs(i * 18 + 12),
                        --             masks_ipbus_regs(i * 18 + 11), masks_ipbus_regs(i * 18 + 10),
                        --             masks_ipbus_regs(i * 18 + 9), masks_ipbus_regs(i * 18 + 8),
                        --             masks_ipbus_regs(i * 18 + 7), masks_ipbus_regs(i * 18 + 6),
                        --             masks_ipbus_regs(i * 18 + 5), masks_ipbus_regs(i * 18 + 4),
                        --             masks_ipbus_regs(i * 18 + 3), masks_ipbus_regs(i * 18 + 2),
                        --             masks_ipbus_regs(i * 18 + 1), masks_ipbus_regs(i * 18 + 0));
                    end if;
                end if;
            end process;
        end generate;
    end generate;
    -- TODO What happens if I want to change the N_TRIGGER constant?? Need to change te code to support that

    ----------------------------------------------------------------------------------
    ------------------VETO MASKS REGISTERS--------------------------------------------
    ----------------------------------------------------------------------------------

    veto_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_SLR_ALGOS_MAX / 32),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_VETO_MASK),
            ipb_out => ipb_from_slaves(N_SLV_VETO_MASK),
            rclk    => clk40,
            we      => '0',
            d       => (others => '0'),
            q       => q_veto,
            addr    => std_logic_vector(addr_veto)
        );

    process(clk40)
    begin
        if rising_edge(clk40) then
            -----------Veto masks------------------------------------
            veto_ipbus_regs(to_integer(unsigned(addr_veto_w))) <= q_veto;
        end if;
    end process;

    veto_reg_l : for j in N_SLR_ALGOS_MAX / 32 - 1 downto 0 generate
        process(clk40)
        begin
            if rising_edge(clk40) then
                if (ready_veto = '1' and ready_veto_1 = '0') then --rising edge
                    veto_mask((j + 1) * 32 - 1 downto j * 32) <= veto_ipbus_regs(j);
                    --veto_mask <= (veto_ipbus_regs(17), veto_ipbus_regs(16),
                    --            veto_ipbus_regs(15), veto_ipbus_regs(14),
                    --              veto_ipbus_regs(13), veto_ipbus_regs(12),
                    --              veto_ipbus_regs(11), veto_ipbus_regs(10),
                    --              veto_ipbus_regs(9), veto_ipbus_regs(8),
                    --              veto_ipbus_regs(7), veto_ipbus_regs(6),
                    --              veto_ipbus_regs(5), veto_ipbus_regs(4),
                    --              veto_ipbus_regs(3), veto_ipbus_regs(2),
                    --              veto_ipbus_regs(1), veto_ipbus_regs(0));
                end if;
            end if;
        end process;
    end generate;
    -- TODO What happens if I want to change the N_ALGOS?? Need to change te code to support that

    veto_update_i : entity work.update_process
        generic map(
            WIDTH      => NR_ALGOS,
            INIT_VALUE => NULL_VETO_MASK
        )
        port map(
            clk                  => clk40,
            request_update_pulse => request_veto_update,
            update_pulse         => end_lumi_per,
            data_i               => veto_mask(NR_ALGOS - 1 downto 0),
            data_o               => veto_mask_int
        );

    ----------------------------------------------------------------------------------
    ---------------ALGO BX MASK MEM---------------------------------------------------
    ----------------------------------------------------------------------------------

    algo_bx_mask_mem_i : entity work.ipbus_dpram_4096x576
        generic map(
            DATA_FILE_32b => "bxmask_113bx_window.mif",
            DEFAULT_VALUE => (others => '1'),
            DATA_WIDTH    => NR_ALGOS
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_ALGO_BX_MASKS),
            ipb_out => ipb_from_slaves(N_SLV_ALGO_BX_MASKS),
            rclk    => clk40,
            we      => '0',
            d       => (others => '1'),
            q       => algo_bx_mask_mem_out,
            addr    => ctrs_reg.bctr    -- note that this one is not delayed

        );

    delay_element_algos_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => NR_ALGOS + 1,
            MAX_DELAY  => MAX_DELAY,
            STYLE      => "block"
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => algos_after_prescaler & valid_algos_in,
            data_o    => algos_delayed_with_valid,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );

    algos_delayed       <= algos_delayed_with_valid(NR_ALGOS - 1 downto 0);
    valid_algos_delayed <= algos_delayed_with_valid(NR_ALGOS);

    ----------------------------------------------------------------------------------
    ---------------Suppress Trigger during Calibration--------------------------------
    ----------------------------------------------------------------------------------    

    suppress_cal_trigger_p : process(clk40)
    begin
        if rising_edge(clk40) then
            if (test_en = '1' and (unsigned(ctrs_internal.bctr) >= (unsigned(supp_cal_BX_low) - 1)) and (unsigned(ctrs_internal.bctr) < unsigned(supp_cal_BX_high))) then -- minus 1 to get correct length of gap (see simulation with test_bgo_test_enable_logic_tb.vhd)
                suppress_cal_trigger <= '1'; -- pos. active signal: '1' = suppression of algos caused by calibration trigger during gap !!!
            else
                suppress_cal_trigger <= '0';
            end if;
        end if;
    end process suppress_cal_trigger_p;

    ----------------------------------------------------------------------------------
    ---------------------------------Algo Slices--------------------------------------
    ----------------------------------------------------------------------------------    

    gen_algos_slice_l : for i in 0 to NR_ALGOS - 1 generate
        algos_slice_i : entity work.algo_slice
            generic map(
                EXCLUDE_ALGO_VETOED   => TRUE,
                RATE_COUNTER_WIDTH    => RATE_COUNTER_WIDTH,
                PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
                PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
            )
            port map(
                clk40                               => clk40,
                rst40                               => rst40,
                sres_algo_rate_counter              => '0',
                sres_algo_pre_scaler                => rst_prescale_counters,
                sres_algo_pre_scaler_preview        => rst_prescale_preview_counters,
                sres_algo_post_dead_time_counter    => '0',
                suppress_cal_trigger                => suppress_cal_trigger,
                l1a                                 => ctrs_internal.l1a, --TODO modify this
                request_update_factor_pulse         => request_factor_update,
                request_update_factor_preview_pulse => request_factor_preview_update,
                begin_lumi_per                      => begin_lumi_per,
                end_lumi_per                        => end_lumi_per,
                algo_i                              => algos_in(i) and valid_algos_in,
                algo_after_prscl_del_i              => algos_delayed(i) and valid_algos_delayed,
                prescale_factor                     => prscl_fct(i)(PRESCALE_FACTOR_WIDTH - 1 downto 0),
                prescale_factor_preview             => prscl_fct_prvw(i)(PRESCALE_FACTOR_WIDTH - 1 downto 0),
                algo_bx_mask                        => algo_bx_mask_mem_out(i),
                veto_mask                           => veto_mask_int(i),
                rate_cnt_before_prescaler           => rate_cnt_before_prescaler(i),
                rate_cnt_after_prescaler            => rate_cnt_after_prescaler(i),
                rate_cnt_after_prescaler_preview    => rate_cnt_after_prescaler_preview(i),
                rate_cnt_post_dead_time             => rate_cnt_post_dead_time(i),
                algo_after_bxomask                  => algos_after_bxmask(i),
                algo_after_prescaler                => algos_after_prescaler(i),
                algo_after_prescaler_preview        => algos_after_prescaler_preview(i),
                veto                                => veto(i)
            );
    end generate;

    algos_after_bxmask_o    <= algos_after_bxmask;
    algos_after_prescaler_o <= algos_after_prescaler;

    ----------------------------------------------------------------------------------
    -----------------------Trigger masks and veto-------------------------------------
    ----------------------------------------------------------------------------------   

    Mask_i : entity work.Mask
        generic map(
            NR_ALGOS => NR_ALGOS,
            OUT_REG  => TRUE
        )
        port map(
            clk                        => clk40,
            algos_in                   => algos_after_prescaler,
            valid_in                   => valid_algos_in,
            masks                      => masks,
            request_masks_update_pulse => request_masks_update,
            update_pulse               => end_lumi_per,
            trigger_out                => trigger_out,
            valid_out                  => valid_trigger_o
        );

    Mask_previev_i : entity work.Mask
        generic map(
            NR_ALGOS => NR_ALGOS,
            OUT_REG  => TRUE
        )
        port map(
            clk                        => clk40,
            algos_in                   => algos_after_prescaler_preview,
            valid_in                   => valid_algos_in,
            masks                      => masks,
            request_masks_update_pulse => request_masks_update,
            update_pulse               => end_lumi_per,
            trigger_out                => trigger_out_preview,
            valid_out                  => open
        );

    ----------------------------------------------------------------------------------
    -----------------------------Veto Rate Counter------------------------------------
    ----------------------------------------------------------------------------------   

    Veto_rate_counter_i : entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk40           => clk40,
            rst40           => rst40,
            sres_counter    => '0',
            store_cnt_value => begin_lumi_per_del1,
            algo_i          => veto_out_s,
            counter_o       => veto_cnt
        );

    Veto_cnt_regs : entity work.ipbus_ctrlreg_cdc_v
        generic map(
            N_CTRL         => 0,
            N_STAT         => 1,
            DEST_SYNC_FF   => 3,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_VETO_REG),
            ipb_out => ipb_from_slaves(N_SLV_VETO_REG),
            slv_clk => clk40,
            d       => veto_stat_reg,
            q       => open,
            qmask   => open,
            stb     => open
        );

    veto_stat_reg(0)(RATE_COUNTER_WIDTH - 1 downto 0) <= veto_cnt;

    veto_reg_p : process(clk40)
    begin
        if rising_edge(clk40) then
            veto_out_s <= or veto;
        end if;
    end process;

    BX_trigger_p : process(clk40)
    begin
        if rising_edge(clk40) then
            BX_nr_trigger <= ctrs_internal.bctr;
        end if;
    end process;

    start_of_orbit_o  <= '1' when BX_nr_trigger = std_logic_vector(to_unsigned(0, 12)) and valid_trigger_o = '1' else '0';
    trigger_o         <= trigger_out;
    trigger_preview_o <= trigger_out_preview;
    veto_o            <= veto_out_s;

end architecture rtl;
