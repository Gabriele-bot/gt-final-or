library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.emp_data_types.all;
use work.emp_project_decl.all;
use work.ipbus_decode_SLR_FinOR_unit.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity SLR_FinOR_unit is
    generic(
        NR_LINKS              : natural := INPUT_LINKS_SLR;
        NR_MON_REG            : natural := MON_REG;
        BEGIN_LUMI_TOGGLE_BIT : natural := 18;
        MAX_DELAY             : natural := MAX_DELAY_PDT
    );
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        ipb_in    : in  ipb_wbus;
        ipb_out   : out ipb_rbus;
        --====================================================================--
        clk360    : in std_logic;
        rst360    : in std_logic;
        lhc_clk   : in std_logic;
        lhc_rst   : in std_logic;
        ctrs      : in ttc_stuff_array(NR_MON_REG - 1 downto 0);
        d         : in ldata(NR_LINKS - 1 downto 0);  -- data in
        trigger_o          : out std_logic_vector(N_TRIGG-1 downto 0);
        trigger_preview_o  : out std_logic_vector(N_TRIGG-1 downto 0);
        valid_out          : out std_logic;
        veto_o             : out std_logic;
        algos              : out std_logic_vector(64*9-1 downto 0);
        algos_after_bxmask : out std_logic_vector(64*9-1 downto 0);
        algos_prescaled    : out std_logic_vector(64*9-1 downto 0)

    );
end entity SLR_FinOR_unit;

architecture RTL of SLR_FinOR_unit is

    constant LATENCY_360 : integer := 9  + 1;

    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

    signal valid_deser_out : std_logic;
    signal d_valids        : std_logic_vector(NR_LINKS - 1 downto 0);

    signal d_reg : ldata(NR_LINKS - 1 downto 0);
    signal links_data : data_arr;

    signal algos_in                : std_logic_vector(64*9-1 downto 0);
    signal algos_after_prescaler   : std_logic_vector(64*9-1 downto 0);

    signal d_left, d_right: ldata(1 downto 0);
    signal d_res : lword;

    signal trigger_out            : std_logic_vector(N_TRIGG-1 downto 0);
    signal trigger_out_preview    : std_logic_vector(N_TRIGG-1 downto 0);
    signal veto_out               : std_logic;

    signal ctrs_int               : ttc_stuff_t;
    signal ctrs_del               : ttc_stuff_array(1 downto 0);

    signal ctrl_reg     : ipb_reg_v(1 downto 0) := ((others => '0'),(others => '1'));
    signal ctrl_reg_stb : ipb_reg_v(1 downto 0) := ((others => '0'),(others => '1'));
    signal stat_reg     : ipb_reg_v(0 downto 0);
    signal ctrl_stb     : std_logic_vector(1 downto 0);

    signal link_mask       : std_logic_vector(NR_LINKS - 1 downto 0);
    signal rst_align_error : std_logic;
    signal align_error     : std_logic;

begin

    fabric_i: entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_SLR_FinOR_unit(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    process(clk360)
    begin
        if rising_edge(clk360) then
            d_reg <= d;
        end if;
    end process;

    CSR_regs : entity work.ipbus_ctrlreg_v
        generic map(
            N_CTRL     => 2,
            N_STAT     => 1
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

    xpm_cdc_linkmask : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF   => 3,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1,
            WIDTH          => NR_LINKS
        )
        port map (
            dest_out => link_mask,
            dest_clk => clk360,
            src_clk  => clk,
            src_in   => ctrl_reg_stb(0)(NR_LINKS - 1 downto 0)
        );

    xpm_cdc_rst_error : xpm_cdc_single
        generic map (
            DEST_SYNC_FF   => 3,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map (
            dest_out => rst_align_error,
            dest_clk => clk360,
            src_clk  => clk,
            src_in   => ctrl_reg(1)(0) and ctrl_stb(1)
        );

    xpm_cdc_error_flag : xpm_cdc_single
        generic map (
            DEST_SYNC_FF   => 3,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map (
            dest_out => stat_reg(0)(0),
            dest_clk => clk,
            src_clk  => clk360,
            src_in   => align_error
        );

    stat_reg(0)(31 downto 1) <= (others => '0');

    Right_merge : entity work.Link_merger
        generic map(
            NR_LINKS => NR_LINKS/2
        )
        port map(
            clk_p     => clk360,
            rst_p     => rst360,
            link_mask => link_mask(NR_LINKS/2 - 1 downto 0),
            d         => d_reg(NR_LINKS/2 - 1 downto 0),
            q         => d_right(0)
        ) ;

    Left_merge : entity work.Link_merger
        generic map(
            NR_LINKS => NR_LINKS/2
        )
        port map(
            clk_p     => clk360,
            rst_p     => rst360,
            link_mask => link_mask(NR_LINKS - 1 downto NR_LINKS/2),
            d         => d_reg(NR_LINKS - 1 downto NR_LINKS/2),
            q         => d_left(0)
        ) ;

    process(clk360)
    begin
        if rising_edge(clk360) then
            d_left(1)  <= d_left(0);
            d_right(1) <= d_right(0);
        end if;
    end process;

    Last_merge : entity work.Link_merger
        generic map(
            NR_LINKS => 2
        )
        port map(
            clk_p     => clk360,
            rst_p     => rst360,
            link_mask => (others => '1'),
            d(0)      => d_left(1),
            d(1)      => d_right(1),
            q         => d_res
        ) ;

    deser_i : entity work.In_deser
        generic map(
            OUT_REG => DESER_OUT_REG
        )
        port map(
            clk360       => clk360,
            lhc_clk      => lhc_clk,
            lhc_rst      => lhc_rst,
            lane_data_in => d_res,
            rst_err      => rst_align_error,
            align_err_o  => align_error,
            demux_data_o => algos_in,
            valid_out    => valid_deser_out
        );


    algos <= algos_in;


    ----------------------------------------------------------------------------------
    ---------------COUNTERS INTERNAL---------------------------------------------------
    ----------------------------------------------------------------------------------
    --TODO Where to stat counting, need some latency? How much?

    ctrs_del(0) <= ctrs(0);
    ctrs_del_p: process(lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            ctrs_del(1) <= ctrs_del(0);
        end if;
    end process;


    crts_del_g: if DESER_OUT_REG generate
        ctrs_int <= ctrs_del(1);
    else generate
        ctrs_int <= ctrs_del(0);
    end generate;



    monitoring_module : entity work.m_module
        generic map(
            NR_ALGOS              => 64*9,
            PRESCALE_FACTOR_INIT  => X"00000064", --1.00,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY
        )
        port map(
            clk                     => clk,
            rst                     => rst,
            ipb_in                  => ipb_to_slaves(N_SLV_MONITORING_MODULE),
            ipb_out                 => ipb_from_slaves(N_SLV_MONITORING_MODULE),
            lhc_clk                 => lhc_clk,
            lhc_rst                 => lhc_rst,
            ctrs                    => ctrs_int,
            algos_in                => algos_in,
            valid_algos_in          => valid_deser_out,
            algos_after_bxmask_o    => algos_after_bxmask, 
            algos_after_prescaler_o => algos_prescaled,
            trigger_o               => trigger_out,
            trigger_preview_o       => trigger_out_preview,
            valid_trigger_o         => valid_out,
            veto_o                  => veto_out
        );
    
    trigger_o         <= trigger_out;
    trigger_preview_o <= trigger_out_preview;
    veto_o            <= veto_out;

end architecture RTL;