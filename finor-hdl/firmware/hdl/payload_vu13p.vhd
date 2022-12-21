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
    
    signal valid_out_SLR2_regs, valid_out_SLR3_regs : std_logic_vector(SLR_CROSSING_LATENCY downto 0);
    signal valid_in                                 : std_logic;

    -- Register object data at arrival in SLR, at departure, and several times in the middle.
    type SLRCross_trigg_t is array (SLR_CROSSING_LATENCY downto 0) of std_logic_vector(7 downto 0);
    signal trgg_SLR2_regs      : SLRCross_trigg_t;
    signal trgg_prvw_SLR2_regs : SLRCross_trigg_t;
    signal veto_SLR2_regs      : std_logic_vector(SLR_CROSSING_LATENCY downto 0);
    signal trgg_SLR3_regs      : SLRCross_trigg_t;
    signal trgg_prvw_SLR3_regs : SLRCross_trigg_t;
    signal veto_SLR3_regs      : std_logic_vector(SLR_CROSSING_LATENCY downto 0);


    signal algos_SLR3       : std_logic_vector(64*9-1 downto 0);
    signal algos_SLR2       : std_logic_vector(64*9-1 downto 0);
    signal algos_presc_SLR3 : std_logic_vector(64*9-1 downto 0);
    signal algos_presc_SLR2 : std_logic_vector(64*9-1 downto 0);

    type SLRCross_algos_t is array (SLR_CROSSING_LATENCY downto 0) of std_logic_vector(64*9-1 downto 0);
    signal algos_SLR3_regs       : SLRCross_algos_t;
    signal algos_presc_SLR3_regs : SLRCross_algos_t;
    signal algos_SLR2_regs       : SLRCross_algos_t;
    signal algos_presc_SLR2_regs : SLRCross_algos_t;

    attribute keep : boolean;
    attribute keep of trgg_SLR3_regs           : signal is true;
    attribute keep of trgg_SLR2_regs           : signal is true;
    attribute keep of trgg_prvw_SLR3_regs      : signal is true;
    attribute keep of trgg_prvw_SLR2_regs      : signal is true;
    attribute keep of veto_SLR3_regs           : signal is true;
    attribute keep of veto_SLR2_regs           : signal is true;
    attribute keep of valid_out_SLR2_regs      : signal is true;
    attribute keep of valid_out_SLR3_regs      : signal is true;

    attribute keep of algos_SLR3_regs          : signal is DEBUG;
    attribute keep of algos_presc_SLR3_regs    : signal is DEBUG;
    attribute keep of algos_SLR2_regs          : signal is DEBUG;
    attribute keep of algos_presc_SLR2_regs    : signal is DEBUG;

    attribute shreg_extract                             : string;
    attribute shreg_extract of trgg_SLR3_regs           : signal is "no";
    attribute shreg_extract of trgg_SLR2_regs           : signal is "no";
    attribute shreg_extract of trgg_prvw_SLR3_regs      : signal is "no";
    attribute shreg_extract of trgg_prvw_SLR2_regs      : signal is "no";
    attribute shreg_extract of veto_SLR3_regs           : signal is "no";
    attribute shreg_extract of veto_SLR2_regs           : signal is "no";
    attribute shreg_extract of valid_out_SLR2_regs      : signal is "no";
    attribute shreg_extract of valid_out_SLR3_regs      : signal is "no";
    

    attribute shreg_extract of algos_SLR3_regs          : signal is "no";
    attribute shreg_extract of algos_presc_SLR3_regs    : signal is "no";
    attribute shreg_extract of algos_SLR2_regs          : signal is "no";
    attribute shreg_extract of algos_presc_SLR2_regs    : signal is "no";

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


    SLR3_module : entity work.SLR_FinOR_unit
        generic map(
            NR_LINKS              => INPUT_LINKS,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT
        )
        port map(
            clk              => clk,
            rst              => rst,
            ipb_in           => ipb_to_slaves(N_SLV_SLR3_MONITOR),
            ipb_out          => ipb_from_slaves(N_SLV_SLR3_MONITOR),
            clk360           => clk_p,
            rst360           => rst_loc(12),
            lhc_clk          => clk_payload(2),
            lhc_rst          => rst_payload(2),
            ctrs(2 downto 0) => ctrs(14 downto 12),
            ctrs(5 downto 3) => ctrs(19 downto 17),
            d(11 downto 0)   => d(59 downto 48), -- regions[12,13,14]
            d(23 downto 12)  => d(79 downto 68), -- regions[17,18,19]
            valid_out         => valid_out_SLR3_regs(0), 
            trigger_o         => trgg_SLR3_regs(0),
            trigger_preview_o => trgg_prvw_SLR3_regs(0),
            veto_o            => veto_SLR3_regs(0),
            algos             => algos_SLR3_regs(0),
            algos_prescaled   => algos_presc_SLR3_regs(0)
        );

    SLR2_module : entity work.SLR_FinOR_unit
        generic map(
            NR_LINKS              => INPUT_LINKS,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY_PDT
        )
        port map(
            clk               => clk,
            rst               => rst,
            ipb_in            => ipb_to_slaves(N_SLV_SLR2_MONITOR),
            ipb_out           => ipb_from_slaves(N_SLV_SLR2_MONITOR),
            clk360            => clk_p,
            rst360            => rst_loc(9),
            lhc_clk           => clk_payload(2),
            lhc_rst           => rst_payload(2),
            ctrs(2 downto 0)  => ctrs(11 downto 9),
            ctrs(5 downto 3)  => ctrs(22 downto 20),
            d(11 downto 0)    => d(47 downto 36),
            d(23 downto 12)   => d(91 downto 80),
            valid_out         => valid_out_SLR2_regs(0), 
            trigger_o         => trgg_SLR2_regs(0),
            trigger_preview_o => trgg_prvw_SLR2_regs(0),
            veto_o            => veto_SLR2_regs(0),
            algos             => algos_SLR2_regs(0),
            algos_prescaled   => algos_presc_SLR2_regs(0)
        );

    cross_SLR : process(clk_p)
    begin
        if rising_edge(clk_p) then
            valid_out_SLR2_regs(valid_out_SLR2_regs'high downto 1) <= valid_out_SLR2_regs(valid_out_SLR2_regs'high - 1 downto 0);
            valid_out_SLR3_regs(valid_out_SLR3_regs'high downto 1) <= valid_out_SLR3_regs(valid_out_SLR3_regs'high - 1 downto 0);
            
            
            trgg_SLR3_regs(trgg_SLR3_regs'high downto 1) <= trgg_SLR3_regs(trgg_SLR3_regs'high - 1 downto 0);
            trgg_SLR2_regs(trgg_SLR2_regs'high downto 1) <= trgg_SLR2_regs(trgg_SLR2_regs'high - 1 downto 0);

            trgg_prvw_SLR3_regs(trgg_prvw_SLR3_regs'high downto 1) <= trgg_prvw_SLR3_regs(trgg_prvw_SLR3_regs'high - 1 downto 0);
            trgg_prvw_SLR2_regs(trgg_prvw_SLR2_regs'high downto 1) <= trgg_prvw_SLR2_regs(trgg_prvw_SLR2_regs'high - 1 downto 0);

            veto_SLR3_regs(veto_SLR3_regs'high downto 1) <= veto_SLR3_regs(veto_SLR3_regs'high - 1 downto 0);
            veto_SLR2_regs(veto_SLR2_regs'high downto 1) <= veto_SLR2_regs(veto_SLR2_regs'high - 1 downto 0);
        end if;
    end process;
    
    valid_in <= valid_out_SLR2_regs(valid_out_SLR2_regs'high) or valid_out_SLR3_regs(valid_out_SLR3_regs'high);

    SLR2_FinalOR_or : entity work.Output_SLR
        generic map(
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY => MAX_DELAY_PDT
        )
        port map(
            clk         => clk,
            rst         => rst,
            ipb_in      => ipb_to_slaves(N_SLV_SLR2_FINOR),
            ipb_out     => ipb_from_slaves(N_SLV_SLR2_FINOR),
            clk_p       => clk_p,
            rst_p       => rst_loc(8),
            lhc_clk     => clk_payload(2),
            lhc_rst     => rst_payload(2),
            ctrs        => ctrs(8),
            valid_in    => valid_in,
            trgg_0      => trgg_SLR2_regs(trgg_SLR2_regs'high),
            trgg_1      => trgg_SLR3_regs(trgg_SLR3_regs'high),
            trgg_prvw_0 => trgg_prvw_SLR2_regs(trgg_prvw_SLR2_regs'high),
            trgg_prvw_1 => trgg_prvw_SLR3_regs(trgg_prvw_SLR3_regs'high),
            veto_0      => veto_SLR2_regs(veto_SLR2_regs'high),
            veto_1      => veto_SLR3_regs(veto_SLR3_regs'high),
            q(0)        => q(35)
        );



    --------------------------------------------------------------------------------
    -------------------------------------------DEBUG OUT----------------------------
    --------------------------------------------------------------------------------

    -- TODO : lots of timing violation with this debug out, need to think about something

    debug_g : if DEBUG generate

        cross_SLR_algo : process(clk_p)
        begin
            if rising_edge(clk_p) then
                algos_SLR3_regs(algos_SLR3_regs'high downto 1) <= algos_SLR3_regs(algos_SLR3_regs'high - 1 downto 0);
                algos_SLR2_regs(algos_SLR2_regs'high downto 1) <= algos_SLR2_regs(algos_SLR2_regs'high - 1 downto 0);

                algos_presc_SLR3_regs(algos_presc_SLR3_regs'high downto 1) <= algos_presc_SLR3_regs(algos_presc_SLR3_regs'high - 1 downto 0);
                algos_presc_SLR2_regs(algos_presc_SLR2_regs'high downto 1) <= algos_presc_SLR2_regs(algos_presc_SLR2_regs'high - 1 downto 0);
            end if;
        end process;



        SLR1_second_algos_out_mux : entity work.mux
            port map(
                clk         => clk_p,
                rst         => rst_loc(25),
                lhc_clk     => clk_payload(2),
                lhc_rst     => rst_payload(2),
                input_40MHz => algos_SLR3_regs(algos_SLR3_regs'high),
                output_data => q(102)
            );

        SLR1_second_algos_prescaled_out_mux : entity work.mux
            port map(
                clk         => clk_p,
                rst         => rst_loc(25),
                lhc_clk     => clk_payload(2),
                lhc_rst     => rst_payload(2),
                input_40MHz => algos_presc_SLR3_regs(algos_presc_SLR3_regs'high),
                output_data => q(103)
            );

        SLR1_first_algos_out_mux : entity work.mux
            port map(
                clk         => clk_p,
                rst         => rst_loc(25),
                lhc_clk     => clk_payload(2),
                lhc_rst     => rst_payload(2),
                input_40MHz => algos_SLR2_regs(algos_SLR2_regs'high),
                output_data => q(100)
            );

        SLR1_first_algos_prescaled_out_mux : entity work.mux
            port map(
                clk         => clk_p,
                rst         => rst_loc(25),
                lhc_clk     => clk_payload(2),
                lhc_rst     => rst_payload(2),
                input_40MHz => algos_presc_SLR2_regs(algos_presc_SLR2_regs'high),
                output_data => q(101)
            );
    end generate;

    gpio    <= (others => '0');
    gpio_en <= (others => '0');

end rtl;
