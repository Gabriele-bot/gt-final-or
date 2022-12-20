library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

--use work.FinOR_pkg.all;

--use work.P2GT_monitor_pkg.all;
--use work.pre_scaler_pkg.all;
use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity SLR_FinOR_unit is
    generic(
        NR_LINKS              : natural := INPUT_LINKS;
        NR_MON_REG            : natural := MON_REG;
        BEGIN_LUMI_TOGGLE_BIT : natural := 18;
        MAX_DELAY             : natural := MAX_DELAY_PDT
    );
    port(
        clk     : in  std_logic;
        rst     : in  std_logic;
        ipb_in  : in  ipb_wbus;
        ipb_out : out ipb_rbus;
        --====================================================================--
        clk360  : in std_logic;
        rst360  : in std_logic;
        lhc_clk : in std_logic;
        lhc_rst : in std_logic;
        ctrs    : in ttc_stuff_array(NR_MON_REG - 1 downto 0);
        d       : in  ldata(NR_LINKS - 1 downto 0);  -- data in
        valid_out         : out std_logic;
        trigger_o         : out std_logic_vector(N_TRIGG-1 downto 0);
        trigger_preview_o : out std_logic_vector(N_TRIGG-1 downto 0);
        veto_o            : out std_logic;
        algos             : out std_logic_vector(64*9-1 downto 0);
        algos_prescaled   : out std_logic_vector(64*9-1 downto 0)

    );
end entity SLR_FinOR_unit;

architecture RTL of SLR_FinOR_unit is

    constant LATENCY_360 : integer := 9  + 1;

    signal valid_shreg : std_logic_vector(LATENCY_360 downto 0);
    signal d_valids    : std_logic_vector(NR_LINKS - 1 downto 0);

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

    signal link_mask              : std_logic_vector(NR_LINKS -1 downto 0) := (others => '1');

begin

    valid_shreg(0) <= d_res.valid;

    process(clk360)
    begin
        if rising_edge(clk360) then
            valid_shreg(LATENCY_360 downto 1) <= valid_shreg(LATENCY_360-1 downto 0);
        end if;
    end process;


    process(clk360)
    begin
        if rising_edge(clk360) then
            d_reg <= d;
        end if;
    end process;

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
            demux_data_o => algos_in
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
            ipb_in                  => ipb_in,
            ipb_out                 => ipb_out,
            lhc_clk                 => lhc_clk,
            lhc_rst                 => lhc_rst,
            ctrs                    => ctrs_int,
            algos_in                => algos_in,
            algos_after_prescaler_o => algos_prescaled,
            trigger_o               => trigger_out,
            trigger_preview_o       => trigger_out_preview,
            veto_o                  => veto_out
        );

    out_reg_g : if DESER_OUT_REG generate
        data_40mhz_p: process(lhc_clk)
        begin
            if rising_edge(lhc_clk) then
                valid_out <= valid_shreg(valid_shreg'high);
            end if;
        end process;
    else generate
        valid_out <= valid_shreg(valid_shreg'high);
    end generate;

    trigger_o         <= trigger_out;
    trigger_preview_o <= trigger_out_preview;
    veto_o            <= veto_out;

end architecture RTL;