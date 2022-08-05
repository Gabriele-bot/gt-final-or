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
        NR_LINKS : natural := INPUT_LINKS
    );
    port(
        clk     : in  std_logic;
        rst     : in  std_logic;
        ipb_in  : in  ipb_wbus;
        ipb_out : out ipb_rbus;
        --====================================================================--
        clk360 : in std_logic;
        rst360  : in std_logic;
        lhc_clk : in std_logic;
        lhc_rst : in std_logic;
        ctrs    : in ttc_stuff_t;
        d       : in  ldata(NR_LINKS - 1 downto 0);  -- data in
        trgg    : out std_logic_vector(N_TRIGG-1 downto 0);
        algos           : out std_logic_vector(64*9-1 downto 0);
        algos_prescaled : out std_logic_vector(64*9-1 downto 0)

    );
end entity SLR_FinOR_unit;

architecture RTL of SLR_FinOR_unit is

    signal links_data : data_arr;

    signal algos_in                : std_logic_vector(64*9-1 downto 0);
    signal algos_after_prescaler   : std_logic_vector(64*9-1 downto 0);

    signal trigger_out             : std_logic_vector(7 downto 0);


begin

    deser_l : for i in 0 to NR_LINKS-1 generate
        deser_i : entity work.In_deser
            port map(
                clk360       => clk360,
                lhc_clk      => lhc_clk,
                lane_data_in => d(i),
                demux_data_o => links_data(i)
            );
    end generate;

    FirstOR_i : entity work.FirstOR
        generic map(
            NR_LINKS => INPUT_LINKS
        )
        port map(
            data_in  => links_data,
            data_out => algos_in
        );

    algos <= algos_in;

    monitoring_module : entity work.m_module
        generic map(
            NR_ALGOS             => 64*9,
            PRESCALE_FACTOR_INIT => X"00000064", --1.00
            MAX_DELAY            => 127
        )
        port map(
            clk                     => clk,
            rst                     => rst,
            ipb_in                  => ipb_in,
            ipb_out                 => ipb_out,
            lhc_clk                 => lhc_clk,
            lhc_rst                 => lhc_rst,
            ctrs                    => ctrs,
            algos_in                => algos_in,
            algos_after_prescaler_o => algos_prescaled,
            trgg_o                  => trigger_out
        );

    trgg <= trigger_out;
    
    
end architecture RTL;
