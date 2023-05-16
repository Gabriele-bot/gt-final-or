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

    -- fabric signals        
    signal ipb_to_slaves   : ipb_wbus_array(N_SLAVES - 1 downto 0);
    signal ipb_from_slaves : ipb_rbus_array(N_SLAVES - 1 downto 0);

    type SLRvalid_t is array (N_MONITOR_SLR - 1 downto 0) of std_logic_vector(SLR_CROSSING_LATENCY downto 0);
    signal valid_out_regs : SLRvalid_t;
    signal valid_in       : std_logic;

    signal ctrs_debug : ttc_stuff_t;

    type SLRCross_delay_t is array (SLR_CROSSING_LATENCY downto 0) of std_logic_vector(log2c(MAX_CTRS_DELAY_360) - 1 downto 0);
    type SLRdelay_t is array (N_MONITOR_SLR - 1 downto 0) of SLRCross_delay_t;
    signal delay_out_regs : SLRdelay_t := (others => (others => std_logic_vector(to_unsigned(MAX_CTRS_DELAY_360, log2c(MAX_CTRS_DELAY_360)))));

    type SLRdelay_lkd_t is array (N_MONITOR_SLR - 1 downto 0) of std_logic_vector(SLR_CROSSING_LATENCY downto 0);
    signal delay_out_lkd_regs : SLRdelay_lkd_t;

    -- Register object data at arrival in SLR, at departure, and several times in the middle.
    type SLRCross_trigg_t is array (SLR_CROSSING_LATENCY downto 0) of std_logic_vector(N_TRIGG - 1 downto 0);
    type SLRtrigg_t is array (N_MONITOR_SLR - 1 downto 0) of SLRCross_trigg_t;
    signal trgg_regs      : SLRtrigg_t;
    signal trgg_prvw_regs : SLRtrigg_t;

    type SLRveto_t is array (N_MONITOR_SLR - 1 downto 0) of std_logic_vector(SLR_CROSSING_LATENCY downto 0);
    signal veto_regs : SLRveto_t;

    type SLRCross_lword_reg_t is array (SLR_CROSSING_LATENCY - 1 downto 0) of lword; -- minus one due to some register in the mux
    type SLRlword_t is array (N_MONITOR_SLR - 1 downto 0) of SLRCross_lword_reg_t;
    signal algos_link_regs        : SLRlword_t;
    signal algos_bxmask_link_regs : SLRlword_t;
    signal algos_presc_link_regs  : SLRlword_t;

    attribute keep : boolean;
    attribute keep of trgg_regs : signal is true;
    attribute keep of trgg_prvw_regs : signal is true;
    attribute keep of veto_regs : signal is true;
    attribute keep of valid_out_regs : signal is true;

    attribute keep of delay_out_regs : signal is true;
    attribute keep of delay_out_lkd_regs : signal is true;

    attribute keep of algos_link_regs : signal is true;
    attribute keep of algos_bxmask_link_regs : signal is true;
    attribute keep of algos_presc_link_regs : signal is true;

    attribute shreg_extract : string;
    attribute shreg_extract of trgg_regs : signal is "no";
    attribute shreg_extract of trgg_prvw_regs : signal is "no";
    attribute shreg_extract of veto_regs : signal is "no";
    attribute shreg_extract of valid_out_regs : signal is "no";

    attribute shreg_extract of delay_out_regs : signal is "no";
    attribute shreg_extract of delay_out_lkd_regs : signal is "no";

    attribute shreg_extract of algos_link_regs : signal is "no";
    attribute shreg_extract of algos_bxmask_link_regs : signal is "no";
    attribute shreg_extract of algos_presc_link_regs : signal is "no";

begin

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

    SLRn2_module : entity work.SLR_Monitoring_unit
        generic map(
            NR_RIGHT_LINKS        => INPUT_R_LINKS_SLR,
            NR_LEFT_LINKS         => INPUT_L_LINKS_SLR,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT
        )
        port map(
            clk                    => clk,
            rst                    => rst,
            ipb_in                 => ipb_to_slaves(N_SLV_SLRn2_MONITOR),
            ipb_out                => ipb_from_slaves(N_SLV_SLRn2_MONITOR),
            clk360                 => clk_p,
            rst360_r               => rst_loc(SLRn2_quads(0)),
            rst360_l               => rst_loc(SLRn2_quads(5)), --TODO need to get rid of the hard coding
            clk40                  => clk_payload(2),
            rst40                  => rst_payload(2),
            ctrs                   => ctrs(SLRn2_quads(0)),
            d(11 downto 0)         => d(SLRn2_channels(11) downto SLRn2_channels(0)),
            d(23 downto 12)        => d(SLRn2_channels(23) downto SLRn2_channels(12)),
            delay_lkd_o            => delay_out_lkd_regs(2)(0),
            delay_o                => delay_out_regs(2)(0),
            trigger_o              => trgg_regs(2)(0),
            trigger_preview_o      => trgg_prvw_regs(2)(0),
            trigger_valid_o        => valid_out_regs(2)(0),
            veto_o                 => veto_regs(2)(0),
            q_algos_o              => algos_link_regs(2)(0),
            q_algos_after_bxmask_o => algos_bxmask_link_regs(2)(0),
            q_algos_after_prscl_o  => algos_presc_link_regs(2)(0)
        );

    SLRn1_module : entity work.SLR_Monitoring_unit
        generic map(
            NR_RIGHT_LINKS        => INPUT_R_LINKS_SLR,
            NR_LEFT_LINKS         => INPUT_L_LINKS_SLR,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT
        )
        port map(
            clk                    => clk,
            rst                    => rst,
            ipb_in                 => ipb_to_slaves(N_SLV_SLRn1_MONITOR),
            ipb_out                => ipb_from_slaves(N_SLV_SLRn1_MONITOR),
            clk360                 => clk_p,
            rst360_r               => rst_loc(SLRn1_quads(0)),
            rst360_l               => rst_loc(SLRn1_quads(5)), --TODO need to get rid of the hard coding
            clk40                  => clk_payload(2),
            rst40                  => rst_payload(2),
            ctrs                   => ctrs(SLRn1_quads(0)),
            d(11 downto 0)         => d(SLRn1_channels(11) downto SLRn1_channels(0)),
            d(23 downto 12)        => d(SLRn1_channels(23) downto SLRn1_channels(12)),
            delay_lkd_o            => delay_out_lkd_regs(1)(0),
            delay_o                => delay_out_regs(1)(0),
            trigger_o              => trgg_regs(1)(0),
            trigger_preview_o      => trgg_prvw_regs(1)(0),
            trigger_valid_o        => valid_out_regs(1)(0),
            veto_o                 => veto_regs(1)(0),
            q_algos_o              => algos_link_regs(1)(0),
            q_algos_after_bxmask_o => algos_bxmask_link_regs(1)(0),
            q_algos_after_prscl_o  => algos_presc_link_regs(1)(0)
        );

    SLRn0_module : entity work.SLR_Monitoring_unit
        generic map(
            NR_RIGHT_LINKS        => INPUT_R_LINKS_SLR,
            NR_LEFT_LINKS         => INPUT_L_LINKS_SLR,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT
        )
        port map(
            clk                    => clk,
            rst                    => rst,
            ipb_in                 => ipb_to_slaves(N_SLV_SLRn0_MONITOR),
            ipb_out                => ipb_from_slaves(N_SLV_SLRn0_MONITOR),
            clk360                 => clk_p,
            rst360_r               => rst_loc(SLRn0_quads(0)),
            rst360_l               => rst_loc(SLRn0_quads(5)), --TODO need to get rid of the hard coding
            clk40                  => clk_payload(2),
            rst40                  => rst_payload(2),
            ctrs                   => ctrs(SLRn0_quads(0)),
            d(11 downto 0)         => d(SLRn0_channels(11) downto SLRn0_channels(0)),
            d(23 downto 12)        => d(SLRn0_channels(23) downto SLRn0_channels(12)),
            delay_lkd_o            => delay_out_lkd_regs(0)(0),
            delay_o                => delay_out_regs(0)(0),
            trigger_o              => trgg_regs(0)(0),
            trigger_preview_o      => trgg_prvw_regs(0)(0),
            trigger_valid_o        => valid_out_regs(0)(0),
            veto_o                 => veto_regs(0)(0),
            q_algos_o              => algos_link_regs(0)(0),
            q_algos_after_bxmask_o => algos_bxmask_link_regs(0)(0),
            q_algos_after_prscl_o  => algos_presc_link_regs(0)(0)
        );

    gen_crossSLR_l : for i in 0 to N_MONITOR_SLR - 1 generate
        cross_SLR : process(clk_p)
        begin
            if rising_edge(clk_p) then
                delay_out_regs(i)(delay_out_regs(i)'high downto 1) <= delay_out_regs(i)(delay_out_regs(i)'high - 1 downto 0);

                delay_out_lkd_regs(i)(delay_out_lkd_regs(i)'high downto 1) <= delay_out_lkd_regs(i)(delay_out_lkd_regs(i)'high - 1 downto 0);

                valid_out_regs(i)(valid_out_regs(i)'high downto 1) <= valid_out_regs(i)(valid_out_regs(i)'high - 1 downto 0);

                trgg_regs(i)(trgg_regs(i)'high downto 1) <= trgg_regs(i)(trgg_regs(i)'high - 1 downto 0);

                trgg_prvw_regs(i)(trgg_prvw_regs(i)'high downto 1) <= trgg_prvw_regs(i)(trgg_prvw_regs(i)'high - 1 downto 0);

                veto_regs(i)(veto_regs(i)'high downto 1) <= veto_regs(i)(veto_regs(i)'high - 1 downto 0);
            end if;
        end process;
    end generate;

    valid_in <= valid_out_regs(0)(valid_out_regs(0)'high) or valid_out_regs(1)(valid_out_regs(1)'high);

    SLRout_FinalOR_or : entity work.SLR_Output
        generic map(
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT
        )
        port map(
            clk         => clk,
            rst         => rst,
            ipb_in      => ipb_to_slaves(N_SLV_SLR_FINOR),
            ipb_out     => ipb_from_slaves(N_SLV_SLR_FINOR),
            clk360      => clk_p,
            rst360      => rst_loc(OUTPUT_QUAD),
            clk40       => clk_payload(2),
            rst40       => rst_payload(2),
            ctrs        => ctrs(OUTPUT_QUAD),
            delay_lkd   => delay_out_lkd_regs(0)(delay_out_lkd_regs(0)'high),
            delay_in    => delay_out_regs(0)(delay_out_regs(0)'high),
            valid_in    => valid_in,
            trgg_0      => trgg_regs(0)(trgg_regs(0)'high),
            trgg_1      => trgg_regs(1)(trgg_regs(1)'high),
            trgg_2      => trgg_regs(2)(trgg_regs(2)'high),
            trgg_prvw_0 => trgg_prvw_regs(0)(trgg_prvw_regs(0)'high),
            trgg_prvw_1 => trgg_prvw_regs(1)(trgg_prvw_regs(1)'high),
            trgg_prvw_2 => trgg_prvw_regs(2)(trgg_prvw_regs(2)'high),
            veto_0      => veto_regs(0)(veto_regs(0)'high),
            veto_1      => veto_regs(1)(veto_regs(1)'high),
            veto_2      => veto_regs(2)(veto_regs(2)'high),
            q(0)        => q(OUTPUT_channel)
        );

    --------------------------------------------------------------------------------
    -------------------------ALGOBITS LINKS SLR CORSSING----------------------------
    --------------------------------------------------------------------------------

    gen_crossSLR_algo_l : for i in 0 to N_MONITOR_SLR - 1 generate
        cross_SLR_algo : process(clk_p)
        begin
            if rising_edge(clk_p) then
                -- unprescaled
                algos_link_regs(i)(algos_link_regs(i)'high downto 1) <= algos_link_regs(0)(algos_link_regs(0)'high - 1 downto 0);

                -- after bxmask
                algos_bxmask_link_regs(i)(algos_bxmask_link_regs(i)'high downto 1) <= algos_bxmask_link_regs(0)(algos_bxmask_link_regs(0)'high - 1 downto 0);

                -- after bxmask prescaled
                algos_presc_link_regs(i)(algos_presc_link_regs(i)'high downto 1) <= algos_presc_link_regs(0)(algos_presc_link_regs(0)'high - 1 downto 0);
            end if;
        end process;
    end generate;

    q(OUTPUT_algo_channels(8)) <= algos_link_regs(2)(algos_link_regs(2)'high);
    q(OUTPUT_algo_channels(7)) <= algos_bxmask_link_regs(2)(algos_bxmask_link_regs(2)'high);
    q(OUTPUT_algo_channels(6)) <= algos_presc_link_regs(2)(algos_presc_link_regs(2)'high);
    q(OUTPUT_algo_channels(5)) <= algos_link_regs(1)(algos_link_regs(1)'high);
    q(OUTPUT_algo_channels(4)) <= algos_bxmask_link_regs(1)(algos_bxmask_link_regs(1)'high);
    q(OUTPUT_algo_channels(3)) <= algos_presc_link_regs(1)(algos_presc_link_regs(1)'high);
    q(OUTPUT_algo_channels(2)) <= algos_link_regs(0)(algos_link_regs(0)'high);
    q(OUTPUT_algo_channels(1)) <= algos_bxmask_link_regs(0)(algos_bxmask_link_regs(0)'high);
    q(OUTPUT_algo_channels(0)) <= algos_presc_link_regs(0)(algos_presc_link_regs(0)'high);

    --------------------------------------------------------------------------------
    ------------------------------DEBUG OUT-----------------------------------------
    --------------------------------------------------------------------------------
    SLRout_ctrs_align_i : entity work.CTRS_fixed_alignment
        generic map(
            MAX_LATENCY_360 => MAX_CTRS_DELAY_360,
            DELAY_OFFSET    => SLR_CROSSING_LATENCY + 9 + 4
        )
        port map(
            clk360         => clk_p,
            rst360         => rst_loc(DEBUG_quads(0)),
            clk40          => clk_payload(2),
            rst40          => rst_payload(2),
            ctrs_delay_lkd => delay_out_lkd_regs(0)(delay_out_lkd_regs(0)'high),
            ctrs_delay_val => delay_out_regs(0)(delay_out_regs(0)'high),
            ctrs_in        => ctrs(DEBUG_quads(0)),
            ctrs_out       => ctrs_debug
        );

    q(DEBUG_channels(0)).data(8 + 1 + 12 + 4 - 1 downto 0) <= ctrs_debug.ttc_cmd & ctrs_debug.l1a & ctrs_debug.bctr & ctrs_debug.pctr;
    q(DEBUG_channels(0)).data(63 downto 8 + 1 + 12 + 4)    <= (others => '0');
    q(DEBUG_channels(0)).start_of_orbit                    <= '1' when (ctrs_debug.bctr = std_logic_vector(to_unsigned(0, 12)) and ctrs_debug.pctr = std_logic_vector(to_unsigned(0, 4))) else '0';
    q(DEBUG_channels(0)).start                             <= '1' when (ctrs_debug.pctr = std_logic_vector(to_unsigned(0, 4))) else '0';
    q(DEBUG_channels(0)).last                              <= '1' when (ctrs_debug.pctr = std_logic_vector(to_unsigned(8, 4))) else '0';
    q(DEBUG_channels(0)).valid                             <= not (rst_loc(DEBUG_quads(0)));

    q(DEBUG_channels(1)).data(8 + 1 + 12 + 4 - 1 downto 0) <= ctrs(DEBUG_quads(1)).ttc_cmd & ctrs(DEBUG_quads(1)).l1a & ctrs(DEBUG_quads(1)).bctr & ctrs(DEBUG_quads(1)).pctr;
    q(DEBUG_channels(1)).data(63 downto 8 + 1 + 12 + 4)    <= (others => '0');
    q(DEBUG_channels(1)).start_of_orbit                    <= '1' when (ctrs(DEBUG_quads(1)).bctr = std_logic_vector(to_unsigned(0, 12)) and ctrs(DEBUG_quads(1)).pctr = std_logic_vector(to_unsigned(0, 4))) else '0';
    q(DEBUG_channels(1)).start                             <= '1' when (ctrs(DEBUG_quads(1)).pctr = std_logic_vector(to_unsigned(0, 4))) else '0';
    q(DEBUG_channels(1)).last                              <= '1' when (ctrs(DEBUG_quads(1)).pctr = std_logic_vector(to_unsigned(8, 4))) else '0';
    q(DEBUG_channels(1)).valid                             <= not (rst_loc(DEBUG_quads(1)));

    gpio    <= (others => '0');
    gpio_en <= (others => '0');

end rtl;
