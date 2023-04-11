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

--use work.P2GT_monitor_pkg.all;
--use work.pre_scaler_pkg.all;
use work.P2GT_finor_pkg.all;

entity emp_payload is
    generic(
        BEGIN_LUMI_TOGGLE_BIT : integer := BEGIN_LUMI_SEC_BIT
    );
    port(
        clk         : in  std_logic;        -- ipbus signals
        rst         : in  std_logic;
        ipb_in      : in  ipb_wbus;
        ipb_out     : out ipb_rbus;
        clk_payload : in  std_logic_vector(2 downto 0);
        rst_payload : in  std_logic_vector(2 downto 0);
        clk_p       : in  std_logic;        -- data clock
        rst_loc     : in  std_logic_vector(N_REGION - 1 downto 0);
        clken_loc   : in  std_logic_vector(N_REGION - 1 downto 0);
        ctrs        : in  ttc_stuff_array;
        bc0         : out std_logic;
        d           : in  ldata(4*N_REGION - 1 downto 0);  -- data in
        q           : out ldata(4*N_REGION - 1 downto 0);  -- data out
        gpio        : out std_logic_vector(29 downto 0);  -- IO to mezzanine connector
        gpio_en     : out std_logic_vector(29 downto 0);  -- IO to mezzanine connector (three-state enables)
        clk40        : in std_logic;
        slink_q      : out slink_input_data_quad_array(SLINK_MAX_QUADS-1 downto 0);
        backpressure : in std_logic_vector(SLINK_MAX_QUADS-1 downto 0)
    );

end emp_payload;

architecture rtl of emp_payload is

    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

    signal begin_lumi_section : std_logic := '0'; -- TODO extract the value from ctrs
    signal l1a_loc            : std_logic_vector(N_REGION - 1 downto 0);
    signal bcres              : std_logic := '0';
    signal bctr_arr_SLRn0     : bctr_array (4 + SLR_CROSSING_LATENCY downto 0);
    signal bctr_arr_SLRn1     : bctr_array (4 + SLR_CROSSING_LATENCY downto 0);
    signal bctr_40_SLRn0      : bctr_t;
    signal bctr_40_SLRn1      : bctr_t;
    signal valid_out_SLRn0_regs, valid_out_SLRn1_regs : std_logic_vector(SLR_CROSSING_LATENCY downto 0);
    signal valid_in                                   : std_logic;
    signal algos_valid_SLRn0, algos_valid_SLRn1       : std_logic;

    -- Register object data at arrival in SLR, at departure, and several times in the middle.
    type SLRCross_trigg_t is array (SLR_CROSSING_LATENCY downto 0) of std_logic_vector(7 downto 0);
    signal trgg_SLRn0_regs      : SLRCross_trigg_t;
    signal trgg_prvw_SLRn0_regs : SLRCross_trigg_t;
    signal veto_SLRn0_regs      : std_logic_vector(SLR_CROSSING_LATENCY downto 0);
    signal trgg_SLRn1_regs      : SLRCross_trigg_t;
    signal trgg_prvw_SLRn1_regs : SLRCross_trigg_t;
    signal veto_SLRn1_regs      : std_logic_vector(SLR_CROSSING_LATENCY downto 0);

    signal algos_SLRn1              : std_logic_vector(64-1 downto 0);
    signal algos_SLRn0              : std_logic_vector(64-1 downto 0);
    signal algos_after_bxmask_SLRn1 : std_logic_vector(64-1 downto 0);
    signal algos_after_bxmask_SLRn0 : std_logic_vector(64-1 downto 0);
    signal algos_presc_SLRn1        : std_logic_vector(64-1 downto 0);
    signal algos_presc_SLRn0        : std_logic_vector(64-1 downto 0);

    type SLRCross_link_reg_t is array (SLR_CROSSING_LATENCY - 1 downto 0) of lword;
    signal algos_link_SLRn1_regs        : SLRCross_link_reg_t;
    signal algos_bxmask_link_SLRn1_regs : SLRCross_link_reg_t;
    signal algos_presc_link_SLRn1_regs  : SLRCross_link_reg_t;
    signal algos_link_SLRn0_regs        : SLRCross_link_reg_t;
    signal algos_bxmask_link_SLRn0_regs : SLRCross_link_reg_t;
    signal algos_presc_link_SLRn0_regs  : SLRCross_link_reg_t;
    
    attribute keep : boolean;
    attribute keep of trgg_SLRn1_regs           : signal is true;
    attribute keep of trgg_SLRn0_regs           : signal is true;
    attribute keep of trgg_prvw_SLRn1_regs      : signal is true;
    attribute keep of trgg_prvw_SLRn0_regs      : signal is true;
    attribute keep of veto_SLRn1_regs           : signal is true;
    attribute keep of veto_SLRn0_regs           : signal is true;
    attribute keep of valid_out_SLRn1_regs      : signal is true;
    attribute keep of valid_out_SLRn0_regs      : signal is true;

    attribute keep of algos_link_SLRn1_regs          : signal is DEBUG;
    attribute keep of algos_bxmask_link_SLRn1_regs   : signal is DEBUG;
    attribute keep of algos_presc_link_SLRn1_regs    : signal is DEBUG;
    attribute keep of algos_link_SLRn0_regs          : signal is DEBUG;
    attribute keep of algos_bxmask_link_SLRn0_regs   : signal is DEBUG;
    attribute keep of algos_presc_link_SLRn0_regs    : signal is DEBUG;

    attribute shreg_extract                            : string;
    attribute shreg_extract of trgg_SLRn1_regs         : signal is "no";
    attribute shreg_extract of trgg_SLRn0_regs         : signal is "no";
    attribute shreg_extract of trgg_prvw_SLRn1_regs    : signal is "no";
    attribute shreg_extract of trgg_prvw_SLRn0_regs    : signal is "no";
    attribute shreg_extract of veto_SLRn1_regs         : signal is "no";
    attribute shreg_extract of veto_SLRn0_regs         : signal is "no";
    attribute shreg_extract of valid_out_SLRn1_regs    : signal is "no";
    attribute shreg_extract of valid_out_SLRn0_regs    : signal is "no";

    attribute shreg_extract of algos_link_SLRn1_regs          : signal is "no";
    attribute shreg_extract of algos_bxmask_link_SLRn1_regs   : signal is "no";
    attribute shreg_extract of algos_presc_link_SLRn1_regs    : signal is "no";
    attribute shreg_extract of algos_link_SLRn0_regs          : signal is "no";
    attribute shreg_extract of algos_bxmask_link_SLRn0_regs   : signal is "no";
    attribute shreg_extract of algos_presc_link_SLRn0_regs    : signal is "no";

begin

    l1a_loc_wiring_gen : for i in N_REGION -1 downto 0 generate
        l1a_loc(i) <= ctrs(i).l1a;
    end generate;


    fabric_i: entity work.ipbus_fabric_sel
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


    SLRn1_module : entity work.SLR_FinOR_unit
        generic map(
            NR_RIGHT_LINKS        => INPUT_R_LINKS_SLR,
            NR_LEFT_LINKS         => INPUT_L_LINKS_SLR,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT
        )
        port map(
            clk                => clk,
            rst                => rst,
            ipb_in             => ipb_to_slaves(N_SLV_SLRn1_MONITOR),
            ipb_out            => ipb_from_slaves(N_SLV_SLRn1_MONITOR),
            clk360             => clk_p,
            rst360             => rst_loc(SLRn1_quads(0)),
            clk40              => clk_payload(2),
            rst40              => rst_payload(2),
            ctrs(2 downto 0)   => ctrs(SLRn1_quads(2) downto SLRn1_quads(0)),
            ctrs(5 downto 3)   => ctrs(SLRn1_quads(5) downto SLRn1_quads(3)),
            d(11 downto 0)     => d(SLRn1_channels(11) downto SLRn1_channels(0) ),
            d(23 downto 12)    => d(SLRn1_channels(23) downto SLRn1_channels(12)),
            trigger_o          => trgg_SLRn1_regs(0),
            trigger_preview_o  => trgg_prvw_SLRn1_regs(0),
            trigger_valid_out  => valid_out_SLRn1_regs(0),
            veto_o             => veto_SLRn1_regs(0),
            algos              => algos_SLRn1,
            algos_after_bxmask => algos_after_bxmask_SLRn1,
            algos_prescaled    => algos_presc_SLRn1,
            algos_valid_out    => algos_valid_SLRn1
        );



    SLRn0_module : entity work.SLR_FinOR_unit
        generic map(
            NR_RIGHT_LINKS        => INPUT_R_LINKS_SLR,
            NR_LEFT_LINKS         => INPUT_L_LINKS_SLR,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT
        )
        port map(
            clk                => clk,
            rst                => rst,
            ipb_in             => ipb_to_slaves(N_SLV_SLRn0_MONITOR),
            ipb_out            => ipb_from_slaves(N_SLV_SLRn0_MONITOR),
            clk360             => clk_p,
            rst360             => rst_loc(SLRn0_quads(0)),
            clk40              => clk_payload(2),
            rst40              => rst_payload(2),
            ctrs(2 downto 0)   => ctrs(SLRn0_quads(2) downto SLRn0_quads(0)),
            ctrs(5 downto 3)   => ctrs(SLRn0_quads(5) downto SLRn0_quads(3)),
            d(11 downto 0)     => d(SLRn0_channels(11) downto SLRn0_channels(0) ),
            d(23 downto 12)    => d(SLRn0_channels(23) downto SLRn0_channels(12)),
            trigger_o          => trgg_SLRn0_regs(0),
            trigger_preview_o  => trgg_prvw_SLRn0_regs(0),
            trigger_valid_out  => valid_out_SLRn0_regs(0),
            veto_o             => veto_SLRn0_regs(0),
            algos              => algos_SLRn0,
            algos_after_bxmask => algos_after_bxmask_SLRn0,
            algos_prescaled    => algos_presc_SLRn0,
            algos_valid_out    => algos_valid_SLRn0
        );



    cross_SLR : process(clk_p)
    begin
        if rising_edge(clk_p) then
            valid_out_SLRn0_regs(valid_out_SLRn0_regs'high downto 1) <= valid_out_SLRn0_regs(valid_out_SLRn0_regs'high - 1 downto 0);
            valid_out_SLRn1_regs(valid_out_SLRn1_regs'high downto 1) <= valid_out_SLRn1_regs(valid_out_SLRn1_regs'high - 1 downto 0);

            trgg_SLRn0_regs(trgg_SLRn0_regs'high downto 1) <= trgg_SLRn0_regs(trgg_SLRn0_regs'high - 1 downto 0);
            trgg_SLRn1_regs(trgg_SLRn1_regs'high downto 1) <= trgg_SLRn1_regs(trgg_SLRn1_regs'high - 1 downto 0);

            trgg_prvw_SLRn0_regs(trgg_prvw_SLRn0_regs'high downto 1) <= trgg_prvw_SLRn0_regs(trgg_prvw_SLRn0_regs'high - 1 downto 0);
            trgg_prvw_SLRn1_regs(trgg_prvw_SLRn1_regs'high downto 1) <= trgg_prvw_SLRn1_regs(trgg_prvw_SLRn1_regs'high - 1 downto 0);

            veto_SLRn0_regs(veto_SLRn0_regs'high downto 1) <= veto_SLRn0_regs(veto_SLRn0_regs'high - 1 downto 0);
            veto_SLRn1_regs(veto_SLRn1_regs'high downto 1) <= veto_SLRn1_regs(veto_SLRn1_regs'high - 1 downto 0);
        end if;
    end process;

    valid_in <= valid_out_SLRn0_regs(valid_out_SLRn0_regs'high) or valid_out_SLRn1_regs(valid_out_SLRn1_regs'high);

    SLRout_FinalOR_or : entity work.Output_SLR
        generic map(
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY => MAX_DELAY_PDT
        )
        port map(
            clk         => clk,
            rst         => rst,
            ipb_in      => ipb_to_slaves(N_SLV_SLR_FINOR),
            ipb_out     => ipb_from_slaves(N_SLV_SLR_FINOR),
            clk360      => clk_p,
            rst360      => rst_loc(OUTPUT_QUAD),
            lhc_clk     => clk_payload(2),
            lhc_rst     => rst_payload(2),
            ctrs        => ctrs(OUTPUT_QUAD),
            valid_in    => valid_in,
            trgg_0      => trgg_SLRn0_regs(trgg_SLRn0_regs'high),
            trgg_1      => trgg_SLRn1_regs(trgg_SLRn1_regs'high),
            trgg_prvw_0 => trgg_prvw_SLRn0_regs(trgg_prvw_SLRn0_regs'high),
            trgg_prvw_1 => trgg_prvw_SLRn1_regs(trgg_prvw_SLRn1_regs'high),
            veto_0      => veto_SLRn0_regs(veto_SLRn0_regs'high),
            veto_1      => veto_SLRn1_regs(veto_SLRn1_regs'high),
            q(0)        => q(OUTPUT_channel)
        );

    gpio    <= (others => '0');
    gpio_en <= (others => '0');

end rtl;