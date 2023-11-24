library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_SLR_Output.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.math_pkg.all;
use work.P2GT_finor_pkg.all;

entity SLR_Output is
    generic(
        NR_TRIGGERS           : natural := N_TRIGG;
        BEGIN_LUMI_TOGGLE_BIT : natural := 18;
        MAX_DELAY             : natural := MAX_DELAY_PDT;
        TMUX2_OUT             : boolean := FALSE
    );
    port(
        clk              : in  std_logic; -- ipbus signals
        rst              : in  std_logic;
        ipb_in           : in  ipb_wbus;
        ipb_out          : out ipb_rbus;
        --==========================================================--
        clk360           : in  std_logic;
        rst360           : in  std_logic;
        clk40            : in  std_logic;
        rst40            : in  std_logic;
        ctrs             : in  ttc_stuff_t;
        valid_in         : in  std_logic;
        start_of_orbit_i : in  std_logic;
        trgg             : in  trigger_array_t;
        trgg_prvw        : in  trigger_array_t;
        veto             : in  std_logic_vector(N_MONITOR_SLR - 1 downto 0);
        veto_prvw        : in  std_logic_vector(N_MONITOR_SLR - 1 downto 0);
        q                : out ldata(0 downto 0) -- data out
    );
end entity SLR_Output;

architecture RTL of SLR_Output is

    constant N_CTRL_REGS : integer := 1;
    constant N_STAT_REGS : integer := 1;

    -- fabric signals        
    signal ipb_to_slaves   : ipb_wbus_array(N_SLAVES - 1 downto 0);
    signal ipb_from_slaves : ipb_rbus_array(N_SLAVES - 1 downto 0);

    signal frame_cntr     : integer range 0 to 17;
    signal start_bit      : std_logic;
    signal start_of_orbit : std_logic;
    signal last           : std_logic;
    signal valid          : std_logic;

    signal valid_in_del                                       : std_logic;
    signal valid_out, start_out, start_of_orbit_out, last_out : std_logic;
    signal link_out                                           : lword;

    signal Final_OR, Final_OR_delayed                                     : std_logic_vector(NR_TRIGGERS - 1 downto 0);
    signal Final_OR_preview, Final_OR_preview_delayed                     : std_logic_vector(NR_TRIGGERS - 1 downto 0);
    signal Final_OR_with_veto, Final_OR_with_veto_delayed                 : std_logic_vector(NR_TRIGGERS - 1 downto 0);
    signal Final_OR_preview_with_veto, Final_OR_preview_with_veto_delayed : std_logic_vector(NR_TRIGGERS - 1 downto 0);

    signal Final_OR_40                   : std_logic_vector(NR_TRIGGERS - 1 downto 0);
    signal Final_OR_preview_40           : std_logic_vector(NR_TRIGGERS - 1 downto 0);
    signal Final_OR_with_veto_40         : std_logic_vector(NR_TRIGGERS - 1 downto 0);
    signal Final_OR_preview_with_veto_40 : std_logic_vector(NR_TRIGGERS - 1 downto 0);

    -- counters and bgos signals
    signal bx_nr_360, bx_nr_40       : p2gt_bctr_t                                              := (others => '0');
    signal delay_measured            : std_logic_vector(log2c(MAX_CTRS_DELAY_360) - 1 downto 0) := std_logic_vector(to_unsigned(MAX_CTRS_DELAY_360, log2c(MAX_CTRS_DELAY_360)));
    signal delay_lkd                 : std_logic;
    signal ttc_bc0, ttc_oc0, ttc_ec0 : std_logic                                                := '0';
    signal ttc_resync, ttc_start     : std_logic;
    signal ttc_test_en               : std_logic;
    signal bc0_reg, oc0_reg, ec0_reg : std_logic                                                := '0';
    signal bc0_40, oc0_40, ec0_40    : std_logic                                                := '0';
    signal resync_reg, start_reg     : std_logic;
    signal resync_40, start_40       : std_logic;
    signal begin_lumi_per            : std_logic;
    signal begin_lumi_per_del1       : std_logic;
    signal end_lumi_per              : std_logic;
    signal l1a_latency_delay         : std_logic_vector(log2c(MAX_DELAY) - 1 downto 0);

    signal ctrs_reg      : ttc_stuff_t;
    signal ctrs_internal : ttc_stuff_t;
    signal ctrs_align    : ttc_stuff_t;

    signal rate_cnt_finor                    : ipb_reg_v(NR_TRIGGERS - 1 downto 0);
    signal rate_cnt_finor_pdt                : ipb_reg_v(NR_TRIGGERS - 1 downto 0);
    signal rate_cnt_finor_prvw               : ipb_reg_v(NR_TRIGGERS - 1 downto 0);
    signal rate_cnt_finor_prvw_pdt           : ipb_reg_v(NR_TRIGGERS - 1 downto 0);
    signal rate_cnt_finor_with_veto          : ipb_reg_v(NR_TRIGGERS - 1 downto 0);
    signal rate_cnt_finor_with_veto_pdt      : ipb_reg_v(NR_TRIGGERS - 1 downto 0);
    signal rate_cnt_finor_prvw_with_veto     : ipb_reg_v(NR_TRIGGERS - 1 downto 0);
    signal rate_cnt_finor_prvw_with_veto_pdt : ipb_reg_v(NR_TRIGGERS - 1 downto 0);

    signal ctrl_reg : ipb_reg_v(N_CTRL_REGS - 1 downto 0) := (others => (others => '0'));
    signal stat_reg : ipb_reg_v(N_STAT_REGS - 1 downto 0) := (others => (others => '0'));

    type state_t is (idle, start, increment);
    signal state : state_t := idle;

    signal addr                                                                 : std_logic_vector(log2c(NR_TRIGGERS) - 1 downto 0);
    signal we                                                                   : std_logic;
    signal ready                                                                : std_logic;
    signal d_rate_cnt_finor, d_rate_cnt_finor_pdt                               : std_logic_vector(31 downto 0);
    signal d_rate_cnt_finor_prvw, d_rate_cnt_finor_prvw_pdt                     : std_logic_vector(31 downto 0);
    signal d_rate_cnt_finor_with_veto, d_rate_cnt_finor_with_veto_pdt           : std_logic_vector(31 downto 0);
    signal d_rate_cnt_finor_prvw_with_veto, d_rate_cnt_finor_prvw_with_veto_pdt : std_logic_vector(31 downto 0);

    signal veto_out_s          : std_logic;
    signal veto_out_40         : std_logic;
    signal veto_cnt            : std_logic_vector(RATE_COUNTER_WIDTH - 1 DOWNTO 0);
    signal veto_preview_out_s  : std_logic;
    signal veto_preview_out_40 : std_logic;
    signal veto_preview_cnt    : std_logic_vector(RATE_COUNTER_WIDTH - 1 DOWNTO 0);
    signal veto_stat_reg       : ipb_reg_v(1 downto 0);

begin

    -- frame counter
    tmux2_frame_counter_g : if TMUX2_OUT generate
        frame_counter_TM2_p : process(clk360)
        begin
            if rising_edge(clk360) then -- rising clock edge
                valid_in_del <= valid_in;
                if valid_in = '0' then
                    frame_cntr <= 0;
                elsif frame_cntr < 17 then
                    frame_cntr <= frame_cntr + 1;
                else
                    frame_cntr <= 0;
                end if;
            end if;
        end process frame_counter_TM2_p;
    else generate
        frame_counter_p : process(clk360)
        begin
            if rising_edge(clk360) then
                valid_in_del <= valid_in;
                if valid_in = '0' then
                    frame_cntr <= 0;
                elsif frame_cntr < 8 then
                    frame_cntr <= frame_cntr + 1;
                else
                    frame_cntr <= 0;
                end if;
            end if;
        end process frame_counter_p;
    end generate;

    tmux2_out_g : if TMUX2_OUT generate
        start_bit      <= '1' when (frame_cntr = 0 and valid_in = '1') else '0';
        start_of_orbit <= '1' when (frame_cntr = 0 and start_of_orbit_i = '1') else '0';
        last           <= '1' when (frame_cntr = 17 and valid_in = '1') else '0';
        valid          <= valid_in;
    else generate
        start_bit      <= '1' when (frame_cntr = 0 and valid_in = '1') else '0';
        start_of_orbit <= '1' when (frame_cntr = 0 and start_of_orbit_i = '1') else '0';
        last           <= '1' when (frame_cntr = 8 and valid_in = '1') else '0';
        valid          <= valid_in;
    end generate;

    fabric_i : entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_slr_output(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    ----------------------------------------------------------------------------------
    ---------------COUNTERS INTERNAL---------------------------------------------------
    ----------------------------------------------------------------------------------

    -----------------------------------------------------------------------------------
    ---------------COUNTERS ALIGN------------------------------------------------------
    -----------------------------------------------------------------------------------

    BX_producer_i : entity work.CTRS_BX_nr_producer
        port map(
            clk360         => clk360,
            rst360         => rst360,
            clk40          => clk40,
            rst40          => rst40,
            valid          => valid,
            last           => last,
            start          => start_bit,
            start_of_orbit => start_of_orbit,
            bx_nr_40       => bx_nr_40,
            bx_nr_360      => bx_nr_360
        );

    BX_delay_i : entity work.CTRS_delay_producer
        generic map(
            MAX_LATENCY_360 => MAX_CTRS_DELAY_360
        )
        port map(
            clk360       => clk360,
            rst360       => rst360,
            clk40        => clk40,
            rst40        => rst40,
            ref_bx_nr    => bx_nr_360,
            ctrs_in      => ctrs,
            --delay_resync => ttc_resync or delay_resync,
            delay_resync => ttc_resync,
            delay_lkd    => delay_lkd,
            delay_val    => delay_measured
        );
    ctrs_align_i : entity work.CTRS_fixed_alignment
        generic map(
            MAX_LATENCY_360 => MAX_CTRS_DELAY_360,
            DELAY_OFFSET    => 0
        )
        port map(
            clk360         => clk360,
            rst360         => rst360,
            clk40          => clk40,
            rst40          => rst40,
            ctrs_delay_lkd => delay_lkd,
            ctrs_delay_val => delay_measured,
            ctrs_in        => ctrs,
            ctrs_out       => ctrs_align
        );

    ----------------------------------------------------------------------------------
    ---------------BGOs SYNC----------------------------------------------------------
    ----------------------------------------------------------------------------------
    BGOs_sync_i : entity work.bgo_sync
        port map(
            clk360            => clk360,
            rst360            => rst360,
            ttc_i             => ctrs_align.ttc_cmd,
            bc0_o             => open,
            ec0_o             => open,
            ec0_sync_bc0_o    => ttc_ec0,
            oc0_o             => open,
            oc0_sync_bc0_o    => ttc_oc0,
            resync_o          => open,
            resync_sync_bc0_o => ttc_resync,
            start_o           => open,
            start_sync_bc0_o  => ttc_start,
            test_en_o         => ttc_test_en
        );

    deser_reg_out_g : if DESER_OUT_REG generate
        process(clk40)
        begin
            if rising_edge(clk40) then
                ctrs_reg   <= ctrs_align;
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
            ctrs_internal <= ctrs_align;
            bc0_40        <= ttc_bc0;
            oc0_40        <= ttc_oc0;
            ec0_40        <= ttc_ec0;
            start_40      <= ttc_start;
            resync_40     <= ttc_resync;
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
            orbit_nr_o     => open,
            lumi_sec_nr    => open,
            begin_lumi_sec => begin_lumi_per,
            end_lumi_sec   => end_lumi_per,
            test_en_o      => open
        );

    rate_cntrs_read_FSM_i : entity work.write_FSM
        generic map(
            RAM_DEPTH => NR_TRIGGERS
        )
        port map(
            clk        => clk40,
            rst        => rst40,
            write_flag => begin_lumi_per_del1,
            addr_o     => addr,
            addr_w_o   => open,
            we_o       => we
        );

    Ctrl_stat_regs : entity work.ipbus_ctrlreg_cdc_v
        generic map(
            N_CTRL         => N_CTRL_REGS,
            N_STAT         => N_STAT_REGS,
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
            stb     => open
        );

    l1a_latency_delay <= ctrl_reg(0)(log2c(MAX_DELAY) - 1 downto 0);

    ready <= not we;

    stat_reg(0)(0) <= ready;

    -- rate counters are updated with begin_lumi_per_del1
    process(clk40)
    begin
        if rising_edge(clk40) then
            begin_lumi_per_del1 <= begin_lumi_per;
        end if;
    end process;

    Finor_gen : case N_MONITOR_SLR generate
        when 1 =>
            Final_OR         <= trgg(0);
            Final_OR_preview <= trgg_prvw(0);
        when 2 =>
            Final_OR         <= trgg(0) or trgg(1);
            Final_OR_preview <= trgg_prvw(0) or trgg_prvw(1);
        when 3 =>
            Final_OR         <= trgg(0) or trgg(1) or trgg(2);
            Final_OR_preview <= trgg_prvw(0) or trgg_prvw(1) or trgg_prvw(2);
        when others =>
            Final_OR         <= trgg(0) or trgg(1) or trgg(2);
            Final_OR_preview <= trgg_prvw(0) or trgg_prvw(1) or trgg_prvw(2);
    end generate;

    Finor_with_veto_l : for i in 0 to NR_TRIGGERS - 1 generate
        Finor_with_veto_i_gen : case N_MONITOR_SLR generate
            when 1 =>
                Final_OR_with_veto(i)         <= trgg(0)(i) and not (or veto);
                Final_OR_preview_with_veto(i) <= trgg_prvw(0)(i) and not (or veto_prvw);
            when 2 =>
                Final_OR_with_veto(i)         <= (trgg(0)(i) or trgg(1)(i)) and not (or veto);
                Final_OR_preview_with_veto(i) <= (trgg_prvw(0)(i) or trgg_prvw(1)(i)) and not (or veto_prvw);
            when 3 =>
                Final_OR_with_veto(i)         <= (trgg(0)(i) or trgg(1)(i) or trgg(2)(i)) and not (or veto);
                Final_OR_preview_with_veto(i) <= (trgg_prvw(0)(i) or trgg_prvw(1)(i) or trgg_prvw(2)(i)) and not (or veto_prvw);
            when others =>
                Final_OR_with_veto(i)         <= (trgg(0)(i) or trgg(1)(i) or trgg(2)(i)) and not (or veto);
                Final_OR_preview_with_veto(i) <= (trgg_prvw(0)(i) or trgg_prvw(1)(i) or trgg_prvw(2)(i)) and not (or veto_prvw);
        end generate;
    end generate;

    process(clk40)
    begin
        if rising_edge(clk40) then
            Final_OR_40                   <= Final_OR;
            Final_OR_preview_40           <= Final_OR_preview;
            Final_OR_with_veto_40         <= Final_OR_with_veto;
            Final_OR_preview_with_veto_40 <= Final_OR_preview_with_veto;
        end if;
    end process;

    delay_element_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => NR_TRIGGERS,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => Final_OR,
            data_o    => Final_OR_delayed,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );

    delay_element_preview_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => NR_TRIGGERS,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => Final_OR_preview,
            data_o    => Final_OR_preview_delayed,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );

    delay_element_veto_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => NR_TRIGGERS,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => Final_OR_with_veto,
            data_o    => Final_OR_with_veto_delayed,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );

    delay_element_preview_veto_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => NR_TRIGGERS,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => Final_OR_preview_with_veto,
            data_o    => Final_OR_preview_with_veto_delayed,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );

    veto_out_s         <= or veto;
    veto_preview_out_s <= or veto_prvw;

    process(clk40)
    begin
        if rising_edge(clk40) then
            veto_out_40         <= veto_out_s;
            veto_preview_out_40 <= veto_preview_out_s;
        end if;
    end process;

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
            algo_i          => veto_out_40,
            counter_o       => veto_cnt
        );

    Veto_preview_rate_counter_i : entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk40           => clk40,
            rst40           => rst40,
            sres_counter    => '0',
            store_cnt_value => begin_lumi_per_del1,
            algo_i          => veto_preview_out_40,
            counter_o       => veto_preview_cnt
        );

    Veto_cnt_regs : entity work.ipbus_ctrlreg_cdc_v
        generic map(
            N_CTRL         => 0,
            N_STAT         => 2,
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
    veto_stat_reg(1)(RATE_COUNTER_WIDTH - 1 downto 0) <= veto_preview_cnt;

    gen_rate_counters_l : for i in 0 to NR_TRIGGERS - 1 generate
        rate_counters_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                algo_i          => Final_OR_40(i),
                counter_o       => rate_cnt_finor(i)
            );

        rate_counters_pdt_i : entity work.algo_rate_counter_pdt
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                l1a             => ctrs_align.l1a,
                algo_del_i      => Final_OR_delayed(i),
                counter_o       => rate_cnt_finor_pdt(i)
            );

        rate_counters_preview_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                algo_i          => Final_OR_preview_40(i),
                counter_o       => rate_cnt_finor_prvw(i)
            );

        rate_counters_preview_pdt_i : entity work.algo_rate_counter_pdt
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                l1a             => ctrs_align.l1a,
                algo_del_i      => Final_OR_preview_delayed(i),
                counter_o       => rate_cnt_finor_prvw_pdt(i)
            );

        rate_counters_veto_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                algo_i          => Final_OR_with_veto_40(i),
                counter_o       => rate_cnt_finor_with_veto(i)
            );

        rate_counters_veto_pdt_i : entity work.algo_rate_counter_pdt
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                l1a             => ctrs_align.l1a,
                algo_del_i      => Final_OR_with_veto_delayed(i),
                counter_o       => rate_cnt_finor_with_veto_pdt(i)
            );

        rate_counters_preview_veto_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                algo_i          => Final_OR_preview_with_veto_40(i),
                counter_o       => rate_cnt_finor_prvw_with_veto(i)
            );

        rate_counters_preview_veto_pdt_i : entity work.algo_rate_counter_pdt
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                l1a             => ctrs_align.l1a,
                algo_del_i      => Final_OR_preview_with_veto_delayed(i),
                counter_o       => rate_cnt_finor_prvw_with_veto_pdt(i)
            );
    end generate;

    d_rate_cnt_finor                    <= rate_cnt_finor(to_integer(unsigned(addr)));
    d_rate_cnt_finor_pdt                <= rate_cnt_finor_pdt(to_integer(unsigned(addr)));
    d_rate_cnt_finor_prvw               <= rate_cnt_finor_prvw(to_integer(unsigned(addr)));
    d_rate_cnt_finor_prvw_pdt           <= rate_cnt_finor_prvw_pdt(to_integer(unsigned(addr)));
    d_rate_cnt_finor_with_veto          <= rate_cnt_finor_with_veto(to_integer(unsigned(addr)));
    d_rate_cnt_finor_with_veto_pdt      <= rate_cnt_finor_with_veto_pdt(to_integer(unsigned(addr)));
    d_rate_cnt_finor_prvw_with_veto     <= rate_cnt_finor_prvw_with_veto(to_integer(unsigned(addr)));
    d_rate_cnt_finor_prvw_with_veto_pdt <= rate_cnt_finor_prvw_with_veto_pdt(to_integer(unsigned(addr)));

    --==================================================================================================--
    --======================================Rate counter RAMs===========================================--
    --==================================================================================================--
    rate_cnt_finor_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_FINOR),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_pdt_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_FINOR_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_pdt,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_preview_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_prvw,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_preview_pdt_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_prvw_pdt,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_with_veto_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_FINOR_WITH_VETO),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_WITH_VETO),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_with_veto,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_with_veto_pdt_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_FINOR_WITH_VETO_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_WITH_VETO_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_with_veto_pdt,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_preview_with_veto_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_WITH_VETO),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_WITH_VETO),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_prvw_with_veto,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_preview_with_veto_pdt_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_TRIGGERS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_WITH_VETO_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_WITH_VETO_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_prvw_with_veto_pdt,
            q       => open,
            addr    => addr
        );
    
    tmux2_data_out_g : if TMUX2_OUT generate
        link_out.data(NR_TRIGGERS - 1 downto 0)                   <= Final_OR when (frame_cntr = 0 or frame_cntr = 9) and valid_in = '1' else (others => '0');
        link_out.data(NR_TRIGGERS * 2 - 1 downto NR_TRIGGERS)     <= Final_OR_preview when (frame_cntr = 0 or frame_cntr = 9) and valid_in = '1' else (others => '0');
        link_out.data(NR_TRIGGERS * 3 - 1 downto 2 * NR_TRIGGERS) <= Final_OR_with_veto when (frame_cntr = 0 or frame_cntr = 9) and valid_in = '1' else (others => '0');
        link_out.data(NR_TRIGGERS * 4 - 1 downto 3 * NR_TRIGGERS) <= Final_OR_preview_with_veto when (frame_cntr = 0 or frame_cntr = 9) and valid_in = '1' else (others => '0');
    else generate
        link_out.data(NR_TRIGGERS - 1 downto 0)                   <= Final_OR when frame_cntr = 0  and valid_in = '1' else (others => '0');
        link_out.data(NR_TRIGGERS * 2 - 1 downto NR_TRIGGERS)     <= Final_OR_preview when frame_cntr = 0 and valid_in = '1' else (others => '0');
        link_out.data(NR_TRIGGERS * 3 - 1 downto 2 * NR_TRIGGERS) <= Final_OR_with_veto when frame_cntr = 0 and valid_in = '1' else (others => '0');
        link_out.data(NR_TRIGGERS * 4 - 1 downto 3 * NR_TRIGGERS) <= Final_OR_preview_with_veto when frame_cntr = 0 and valid_in = '1' else (others => '0');
    end generate;
    link_out.data(LWORD_WIDTH - 1 downto 4 * NR_TRIGGERS)     <= (others => '0');

    link_out.strobe         <= not rst360;
    link_out.valid          <= valid_in;
    link_out.start          <= start_bit;
    link_out.last           <= last;
    link_out.start_of_orbit <= start_of_orbit;

    output_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if (rst360 = '1') then
                q(0).data           <= (others => '0');
                q(0).valid          <= '0';
                q(0).start_of_orbit <= '0';
                q(0).start          <= '0';
                q(0).last           <= '0';
                q(0).strobe         <= '0';
            else
                q(0) <= link_out;
            end if;
        end if;

    end process;

end architecture RTL;
