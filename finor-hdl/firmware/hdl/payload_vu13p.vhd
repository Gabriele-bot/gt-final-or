library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_emp_payload.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.emp_slink_types.all;

use work.P2GT_finor_pkg.all;
use work.math_pkg.all;

entity emp_payload is
    generic(
        BEGIN_LUMI_TOGGLE_BIT : integer := BEGIN_LUMI_SEC_BIT
    );
    port(
        clk          : in  std_logic;   -- ipbus signals
        rst          : in  std_logic;
        ipb_in       : in  ipb_wbus;
        ipb_out      : out ipb_rbus;
        clk_payload  : in  std_logic_vector(2 downto 0);
        rst_payload  : in  std_logic_vector(2 downto 0);
        clk_p        : in  std_logic;   -- data clock
        rst_loc      : in  std_logic_vector(N_REGION - 1 downto 0);
        clken_loc    : in  std_logic_vector(N_REGION - 1 downto 0);
        ctrs         : in  ttc_stuff_array;
        bc0          : out std_logic;
        d            : in  ldata(4 * N_REGION - 1 downto 0); -- data in
        q            : out ldata(4 * N_REGION - 1 downto 0); -- data out
        gpio         : out std_logic_vector(29 downto 0); -- IO to mezzanine connector
        gpio_en      : out std_logic_vector(29 downto 0); -- IO to mezzanine connector (three-state enables)
        clk40        : in  std_logic;
        slink_q      : out slink_input_data_quad_array(SLINK_MAX_QUADS - 1 downto 0);
        backpressure : in  std_logic_vector(SLINK_MAX_QUADS - 1 downto 0)
    );

end emp_payload;

architecture rtl of emp_payload is

    constant RO_DATA : std_logic_vector(31 downto 0) := (1 downto 0   => std_logic_vector(to_signed(N_MONITOR_SLR, 2)),
                                                         11 downto 2  => std_logic_vector(to_signed(N_SLR_ALGOS, 10)),
                                                         15 downto 12 => std_logic_vector(to_signed(N_TRIGG, 4)),
                                                         27 downto 16 => std_logic_vector(to_signed(N_ALGOS, 12)),
                                                         31 downto 28 => X"0"); --Reserved

    constant RO_CHANNEL_DATA : std_logic_vector(95 downto 0) := (7 downto 0   => std_logic_vector(to_signed(SLRn0_OUTPUT_CHANNELS(0), 8)),
                                                                 15 downto 8  => std_logic_vector(to_signed(SLRn0_OUTPUT_CHANNELS(1), 8)),
                                                                 23 downto 16 => std_logic_vector(to_signed(SLRn0_OUTPUT_CHANNELS(2), 8)),
                                                                 31 downto 24 => std_logic_vector(to_signed(SLRn1_OUTPUT_CHANNELS(0), 8)),
                                                                 39 downto 32 => std_logic_vector(to_signed(SLRn1_OUTPUT_CHANNELS(1), 8)),
                                                                 47 downto 40 => std_logic_vector(to_signed(SLRn1_OUTPUT_CHANNELS(2), 8)),
                                                                 55 downto 48 => std_logic_vector(to_signed(SLRn2_OUTPUT_CHANNELS(0), 8)),
                                                                 63 downto 56 => std_logic_vector(to_signed(SLRn2_OUTPUT_CHANNELS(1), 8)),
                                                                 71 downto 64 => std_logic_vector(to_signed(SLRn2_OUTPUT_CHANNELS(2), 8)),
                                                                 79 downto 72 => std_logic_vector(to_signed(OUTPUT_CHANNEL, 8)),
                                                                 95 downto 80 => X"0000"); --Reserved

    -- fabric signals        
    signal ipb_to_slaves   : ipb_wbus_array(N_SLAVES - 1 downto 0);
    signal ipb_from_slaves : ipb_rbus_array(N_SLAVES - 1 downto 0);

    type SLRvalid_t is array (N_MONITOR_SLR - 1 downto 0) of std_logic_vector(SLR_CROSSING_LATENCY_TRIGGERBITS downto 0);
    signal valid_out_regs : SLRvalid_t := (others => (others => '0'));
    signal valid_in       : std_logic  := '0';

    signal ctrs_debug : ttc_stuff_t;

    type SLR_ldata_t is array (N_MONITOR_SLR - 1 downto 0) of ldata(INPUT_LINKS_SLR - 1 downto 0);
    signal d_ldata_slr     : SLR_ldata_t;
    signal d_ldata_slr_reg : SLR_ldata_t;

    -- Register object data at arrival in SLR, at departure, and several times in the middle.
    type SLRCross_trigg_t is array (SLR_CROSSING_LATENCY_TRIGGERBITS downto 0) of std_logic_vector(N_TRIGG - 1 downto 0);
    type SLRtrigg_t is array (N_MONITOR_SLR - 1 downto 0) of SLRCross_trigg_t;
    signal trgg_regs      : SLRtrigg_t := (others => (others => (others => '0')));
    signal trgg_prvw_regs : SLRtrigg_t := (others => (others => (others => '0')));
    signal trgg_conc      : trigger_array_t;
    signal trgg_prvw_conc : trigger_array_t;

    type SLRveto_t is array (N_MONITOR_SLR - 1 downto 0) of std_logic_vector(SLR_CROSSING_LATENCY_TRIGGERBITS downto 0);
    signal veto_regs      : SLRveto_t := (others => (others => '0'));
    signal veto_prvw_regs : SLRveto_t := (others => (others => '0'));
    signal veto_conc      : std_logic_vector(N_MONITOR_SLR - 1 downto 0);
    signal veto_prvw_conc : std_logic_vector(N_MONITOR_SLR - 1 downto 0);

    signal start_of_orbit_regs : std_logic_vector(SLR_CROSSING_LATENCY_TRIGGERBITS downto 0) := (others => '0');

    type SLRCross_lword_reg_t is array (OUTPUT_LATENCY_ALGOBITS - 1 downto 0) of lword; -- minus one due to some register in the mux
    type SLRlword_t is array (N_MONITOR_SLR - 1 downto 0) of SLRCross_lword_reg_t;
    signal algos_link_regs        : SLRlword_t := (others => (others => LWORD_NULL));
    signal algos_bxmask_link_regs : SLRlword_t := (others => (others => LWORD_NULL));
    signal algos_presc_link_regs  : SLRlword_t := (others => (others => LWORD_NULL));

    attribute keep : boolean;
    attribute keep of trgg_regs : signal is true;
    attribute keep of trgg_prvw_regs : signal is true;
    attribute keep of veto_regs : signal is true;
    attribute keep of valid_out_regs : signal is true;
    attribute keep of start_of_orbit_regs : signal is true;

    --attribute keep of algos_link_regs : signal is true;
    --attribute keep of algos_bxmask_link_regs : signal is true;
    --attribute keep of algos_presc_link_regs : signal is true;

    attribute shreg_extract : string;
    attribute shreg_extract of trgg_regs : signal is "no";
    attribute shreg_extract of trgg_prvw_regs : signal is "no";
    attribute shreg_extract of veto_regs : signal is "no";
    attribute shreg_extract of valid_out_regs : signal is "no";
    attribute shreg_extract of start_of_orbit_regs : signal is "no";

    --attribute shreg_extract of algos_link_regs : signal is "no";
    --attribute shreg_extract of algos_bxmask_link_regs : signal is "no";
    --attribute shreg_extract of algos_presc_link_regs : signal is "no";

begin

    assert N_SLR_ALGOS <= N_SLR_ALGOS_MAX
    report "Selected number of algos per SLR is greater than 576"
    severity FAILURE;

    assert N_MONITOR_SLR <= 3
    report "Selected number Monoriting SLR is greater than 3"
    severity FAILURE;

    assert N_MONITOR_SLR /= 0
    report "Selected number Monoriting SLR cannot be 0"
    severity FAILURE;

    Menu_ROM : entity work.ipbus_file_init_menu_sprom
        generic map(
            DATA_FILE     => "menu_algo_string.mif",
            FILE_LENGTH   => N_ALGOS * integer(ALGONAME_MAX_CHARS / 4),
            ADDR_WIDTH    => log2c(N_ALGOS * integer(ALGONAME_MAX_CHARS / 4)),
            DEFAULT_VALUE => X"00100000",
            DATA_WIDTH    => 8 * 4
        )
        port map(
            clk     => clk,
            ipb_in  => ipb_to_slaves(N_SLV_ALGO_NAMES),
            ipb_out => ipb_from_slaves(N_SLV_ALGO_NAMES)
        );

    fabric_i : entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_emp_payload(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    d_SLR_ldata_fill_l : for i in 0 to INPUT_LINKS_SLR - 1 generate
        d_SLR_ldata_fill_g : case N_MONITOR_SLR generate
            when 1 =>
                d_ldata_slr(0)(i) <= d(SLRn0_INPUT_CHANNELS(i));
            when 2 =>
                d_ldata_slr(0)(i) <= d(SLRn0_INPUT_CHANNELS(i));
                d_ldata_slr(1)(i) <= d(SLRn1_INPUT_CHANNELS(i));
            when 3 =>
                d_ldata_slr(0)(i) <= d(SLRn0_INPUT_CHANNELS(i));
                d_ldata_slr(1)(i) <= d(SLRn1_INPUT_CHANNELS(i));
                d_ldata_slr(2)(i) <= d(SLRn2_INPUT_CHANNELS(i));
            when others =>
                d_ldata_slr(0)(i) <= d(SLRn0_INPUT_CHANNELS(i));
                d_ldata_slr(1)(i) <= d(SLRn1_INPUT_CHANNELS(i));
                d_ldata_slr(2)(i) <= d(SLRn2_INPUT_CHANNELS(i));
        end generate;
    end generate;

    reg_link_data_p : process(clk_p)
    begin
        if rising_edge(clk_p) then
            d_ldata_slr_reg <= d_ldata_slr;
        end if;
    end process;

    FinOR_ro_reg : entity work.ipbus_roreg_v
        generic map(
            N_REG               => 4,
            DATA(31 downto 0)   => RO_DATA,
            DATA(127 downto 32) => RO_CHANNEL_DATA
        )
        port map(
            ipb_in  => ipb_to_slaves(N_SLV_FINOR_ROREG),
            ipb_out => ipb_from_slaves(N_SLV_FINOR_ROREG)
        );

    monitoring_module_slr2_g : if N_MONITOR_SLR = 3 generate
        SLRn2_module : entity work.SLR_Monitoring_unit
            generic map(
                NR_RIGHT_LINKS        => INPUT_R_LINKS_SLR,
                NR_LEFT_LINKS         => INPUT_L_LINKS_SLR,
                BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
                MAX_DELAY             => MAX_DELAY_PDT,
                TMUX2_OUT             => TRUE
            )
            port map(
                clk                    => clk,
                rst                    => rst,
                ipb_in                 => ipb_to_slaves(N_SLV_SLRN2_MONITOR),
                ipb_out                => ipb_from_slaves(N_SLV_SLRN2_MONITOR),
                clk360                 => clk_p,
                rst360_r               => rst_loc(SLRn2_INPUT_QUADS(0)),
                rst360_l               => rst_loc(SLRn2_INPUT_QUADS(5)), --TODO need to get rid of the hard coding
                clk40                  => clk_payload(2),
                rst40                  => rst_payload(2),
                ctrs                   => ctrs(SLRn2_INPUT_QUADS(0)),
                d                      => d_ldata_slr_reg(2),
                start_of_orbit_o       => open,
                trigger_o              => trgg_regs(2)(0),
                trigger_preview_o      => trgg_prvw_regs(2)(0),
                trigger_valid_o        => valid_out_regs(2)(0),
                veto_o                 => veto_regs(2)(0),
                veto_preview_o         => veto_prvw_regs(2)(0),
                q_algos_o              => algos_link_regs(2)(0),
                q_algos_after_bxmask_o => algos_bxmask_link_regs(2)(0),
                q_algos_after_prscl_o  => algos_presc_link_regs(2)(0)
            );
    else generate
        -- TODO remove this dirty hack
        ipb_from_slaves(N_SLV_SLRN2_MONITOR).ipb_rdata <= (others => '0');
        ipb_from_slaves(N_SLV_SLRN2_MONITOR).ipb_ack   <= ipb_to_slaves(N_SLV_SLRN2_MONITOR).ipb_strobe;
        ipb_from_slaves(N_SLV_SLRN2_MONITOR).ipb_err   <= '0';
    end generate;

    monitoring_module_slr1_g : if N_MONITOR_SLR >= 2 generate
        SLRn1_module : entity work.SLR_Monitoring_unit
            generic map(
                NR_RIGHT_LINKS        => INPUT_R_LINKS_SLR,
                NR_LEFT_LINKS         => INPUT_L_LINKS_SLR,
                BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
                MAX_DELAY             => MAX_DELAY_PDT,
                TMUX2_OUT             => TRUE
            )
            port map(
                clk                    => clk,
                rst                    => rst,
                ipb_in                 => ipb_to_slaves(N_SLV_SLRN1_MONITOR),
                ipb_out                => ipb_from_slaves(N_SLV_SLRN1_MONITOR),
                clk360                 => clk_p,
                rst360_r               => rst_loc(SLRn1_INPUT_QUADS(0)),
                rst360_l               => rst_loc(SLRn1_INPUT_QUADS(5)), --TODO need to get rid of the hard coding
                clk40                  => clk_payload(2),
                rst40                  => rst_payload(2),
                ctrs                   => ctrs(SLRn1_INPUT_QUADS(0)),
                d                      => d_ldata_slr_reg(1),
                start_of_orbit_o       => open,
                trigger_o              => trgg_regs(1)(0),
                trigger_preview_o      => trgg_prvw_regs(1)(0),
                trigger_valid_o        => valid_out_regs(1)(0),
                veto_o                 => veto_regs(1)(0),
                veto_preview_o         => veto_prvw_regs(1)(0),
                q_algos_o              => algos_link_regs(1)(0),
                q_algos_after_bxmask_o => algos_bxmask_link_regs(1)(0),
                q_algos_after_prscl_o  => algos_presc_link_regs(1)(0)
            );
    else generate
        --ipb_from_slaves(N_SLV_SLRN1_MONITOR) <= IPB_RBUS_NULL;
        -- TODO remove this dirty hack
        ipb_from_slaves(N_SLV_SLRN1_MONITOR).ipb_rdata <= (others => '0');
        ipb_from_slaves(N_SLV_SLRN1_MONITOR).ipb_ack   <= ipb_to_slaves(N_SLV_SLRN1_MONITOR).ipb_strobe;
        ipb_from_slaves(N_SLV_SLRN1_MONITOR).ipb_err   <= '0';
    end generate;

    SLRn0_module : entity work.SLR_Monitoring_unit
        generic map(
            NR_RIGHT_LINKS        => INPUT_R_LINKS_SLR,
            NR_LEFT_LINKS         => INPUT_L_LINKS_SLR,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT,
            TMUX2_OUT             => TRUE
        )
        port map(
            clk                    => clk,
            rst                    => rst,
            ipb_in                 => ipb_to_slaves(N_SLV_SLRN0_MONITOR),
            ipb_out                => ipb_from_slaves(N_SLV_SLRN0_MONITOR),
            clk360                 => clk_p,
            rst360_r               => rst_loc(SLRn0_INPUT_QUADS(0)),
            rst360_l               => rst_loc(SLRn0_INPUT_QUADS(5)), --TODO need to get rid of the hard coding
            clk40                  => clk_payload(2),
            rst40                  => rst_payload(2),
            ctrs                   => ctrs(SLRn0_INPUT_QUADS(0)),
            d                      => d_ldata_slr_reg(0),
            start_of_orbit_o       => start_of_orbit_regs(0),
            trigger_o              => trgg_regs(0)(0),
            trigger_preview_o      => trgg_prvw_regs(0)(0),
            trigger_valid_o        => valid_out_regs(0)(0),
            veto_o                 => veto_regs(0)(0),
            veto_preview_o         => veto_prvw_regs(0)(0),
            q_algos_o              => algos_link_regs(0)(0),
            q_algos_after_bxmask_o => algos_bxmask_link_regs(0)(0),
            q_algos_after_prscl_o  => algos_presc_link_regs(0)(0)
        );

    gen_crossSLR_l : for i in 0 to N_MONITOR_SLR - 1 generate
        cross_SLR : process(clk_p)
        begin
            if rising_edge(clk_p) then
                valid_out_regs(i)(valid_out_regs(i)'high downto 1) <= valid_out_regs(i)(valid_out_regs(i)'high - 1 downto 0);

                trgg_regs(i)(trgg_regs(i)'high downto 1)           <= trgg_regs(i)(trgg_regs(i)'high - 1 downto 0);
                trgg_prvw_regs(i)(trgg_prvw_regs(i)'high downto 1) <= trgg_prvw_regs(i)(trgg_prvw_regs(i)'high - 1 downto 0);

                veto_regs(i)(veto_regs(i)'high downto 1)           <= veto_regs(i)(veto_regs(i)'high - 1 downto 0);
                veto_prvw_regs(i)(veto_prvw_regs(i)'high downto 1) <= veto_prvw_regs(i)(veto_prvw_regs(i)'high - 1 downto 0);
            end if;
        end process;
        trgg_conc(i)      <= trgg_regs(i)(trgg_regs(i)'high);
        trgg_prvw_conc(i) <= trgg_prvw_regs(i)(trgg_prvw_regs(i)'high);
        veto_conc(i)      <= veto_regs(i)(veto_regs(i)'high);
        veto_prvw_conc(i) <= veto_prvw_regs(i)(veto_prvw_regs(i)'high);
    end generate;

    soo_cross_SLR : process(clk_p)
    begin
        if rising_edge(clk_p) then
            start_of_orbit_regs(start_of_orbit_regs'high downto 1) <= start_of_orbit_regs(start_of_orbit_regs'high - 1 downto 0);
        end if;
    end process;

    valid_g : case N_MONITOR_SLR generate
        when 1 =>
            valid_in <= valid_out_regs(0)(valid_out_regs(0)'high);
        when 2 =>
            valid_in <= valid_out_regs(0)(valid_out_regs(0)'high) or valid_out_regs(1)(valid_out_regs(1)'high);
        when 3 =>
            valid_in <= valid_out_regs(0)(valid_out_regs(0)'high) or valid_out_regs(1)(valid_out_regs(1)'high) or valid_out_regs(2)(valid_out_regs(2)'high);
        when others =>
            valid_in <= valid_out_regs(0)(valid_out_regs(0)'high) or valid_out_regs(1)(valid_out_regs(1)'high) or valid_out_regs(2)(valid_out_regs(2)'high);
    end generate;

    SLRout_FinalOR_or : entity work.SLR_Output
        generic map(
            NR_TRIGGERS           => N_TRIGG,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT,
            TMUX2_OUT             => TRUE
        )
        port map(
            clk              => clk,
            rst              => rst,
            ipb_in           => ipb_to_slaves(N_SLV_SLR_FINOR),
            ipb_out          => ipb_from_slaves(N_SLV_SLR_FINOR),
            clk360           => clk_p,
            rst360           => rst_loc(OUTPUT_QUAD),
            clk40            => clk_payload(2),
            rst40            => rst_payload(2),
            ctrs             => ctrs(OUTPUT_QUAD),
            valid_in         => valid_in,
            start_of_orbit_i => start_of_orbit_regs(start_of_orbit_regs'high),
            trgg             => trgg_conc,
            trgg_prvw        => trgg_prvw_conc,
            veto             => veto_conc,
            veto_prvw        => veto_prvw_conc,
            q(0)             => q(OUTPUT_CHANNEL)
        );

    --------------------------------------------------------------------------------
    --------------------ALGOBITS LINKS SLR CORSSING LATENCY-------------------------
    --------------------------------------------------------------------------------

    gen_crossSLR_latency_algo_l : for i in 0 to N_MONITOR_SLR - 1 generate
        delay_SLR_algos_link : process(clk_p)
        begin
            if rising_edge(clk_p) then
                -- unprescaled
                algos_link_regs(i)(algos_link_regs(i)'high downto 1) <= algos_link_regs(i)(algos_link_regs(i)'high - 1 downto 0);

                -- after bxmask
                algos_bxmask_link_regs(i)(algos_bxmask_link_regs(i)'high downto 1) <= algos_bxmask_link_regs(i)(algos_bxmask_link_regs(i)'high - 1 downto 0);

                -- after bxmask prescaled
                algos_presc_link_regs(i)(algos_presc_link_regs(i)'high downto 1) <= algos_presc_link_regs(i)(algos_presc_link_regs(i)'high - 1 downto 0);
            end if;
        end process;
    end generate;

    gen_output_slr2 : if N_MONITOR_SLR >= 3 generate
        q(SLRn2_OUTPUT_CHANNELS(0)) <= algos_link_regs(2)(algos_link_regs(2)'high);
        q(SLRn2_OUTPUT_CHANNELS(1)) <= algos_bxmask_link_regs(2)(algos_bxmask_link_regs(2)'high);
        q(SLRn2_OUTPUT_CHANNELS(2)) <= algos_presc_link_regs(2)(algos_presc_link_regs(2)'high);
    else generate
        q(SLRn2_OUTPUT_CHANNELS(0)) <= LWORD_NULL;
        q(SLRn2_OUTPUT_CHANNELS(1)) <= LWORD_NULL;
        q(SLRn2_OUTPUT_CHANNELS(2)) <= LWORD_NULL;
    end generate;
    gen_output_slr1 : if N_MONITOR_SLR >= 2 generate
        q(SLRn1_OUTPUT_CHANNELS(0)) <= algos_link_regs(1)(algos_link_regs(1)'high);
        q(SLRn1_OUTPUT_CHANNELS(1)) <= algos_bxmask_link_regs(1)(algos_bxmask_link_regs(1)'high);
        q(SLRn1_OUTPUT_CHANNELS(2)) <= algos_presc_link_regs(1)(algos_presc_link_regs(1)'high);
    else generate
        q(SLRn1_OUTPUT_CHANNELS(0)) <= LWORD_NULL;
        q(SLRn1_OUTPUT_CHANNELS(1)) <= LWORD_NULL;
        q(SLRn1_OUTPUT_CHANNELS(2)) <= LWORD_NULL;
    end generate;
    q(SLRn0_OUTPUT_CHANNELS(0)) <= algos_link_regs(0)(algos_link_regs(0)'high);
    q(SLRn0_OUTPUT_CHANNELS(1)) <= algos_bxmask_link_regs(0)(algos_bxmask_link_regs(0)'high);
    q(SLRn0_OUTPUT_CHANNELS(2)) <= algos_presc_link_regs(0)(algos_presc_link_regs(0)'high);

    gpio    <= (others => '0');
    gpio_en <= (others => '0');

end rtl;
