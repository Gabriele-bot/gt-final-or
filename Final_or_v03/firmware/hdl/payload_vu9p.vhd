library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_Finor.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;


use work.P2GT_monitor_pkg.all;
use work.pre_scaler_pkg.all;

entity emp_payload is
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
        gpio_en     : out std_logic_vector(29 downto 0)  -- IO to mezzanine connector (three-state enables)
    );

end emp_payload;

architecture rtl of emp_payload is

    constant SLR_CROSSING_LATENCY : natural := 9;
    
    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

    signal begin_lumi_section : std_logic := '0'; -- TODO extract the value from ctrs
    signal l1a_loc            : std_logic_vector(N_REGION - 1 downto 0);
    signal bcres              : std_logic := '0';

    -- Register object data at arrival in SLR, at departure, and several times in the middle.
    type SLRCross_type is array (SLR_CROSSING_LATENCY - 1 downto 0) of std_logic_vector(7 downto 0);
    signal trgg_SLR0_regs : SLRCross_type;
    signal trgg_SLR2_regs : SLRCross_type;
    
    
    attribute shreg_extract                       : string;
    attribute shreg_extract of trgg_SLR0_regs     : signal is "no";
    attribute shreg_extract of trgg_SLR2_regs     : signal is "no";



begin

    l1a_loc_wiring_gen : for i in N_REGION -1 downto 0 generate
        l1a_loc(i) <= ctrs(i).l1a;
    end generate;
    
    
    fabric_i: entity work.ipbus_fabric_sel
        generic map(
            NSLV => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_Finor(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );
    

    SLR0_module : entity work.SLR_FinOR_unit
        generic map(
            NR_LINKS => 24
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_SLR0_MONITOR),
            ipb_out => ipb_from_slaves(N_SLV_SLR0_MONITOR),
            clk360  => clk_p,
            rst360  => rst_loc(1),
            lhc_clk => clk_payload(2),
            lhc_rst => rst_payload(2),
            l1a     => l1a_loc(1),
            d(11 downto 0)  => d(15 downto 4),    --1  2  3
            d(23 downto 12) => d(115 downto 104), --26 27 28
            trgg    => trgg_SLR0_regs(0)
        );

    SLR2_module : entity work.SLR_FinOR_unit
        generic map(
            NR_LINKS => 24
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_SLR2_MONITOR),
            ipb_out => ipb_from_slaves(N_SLV_SLR2_MONITOR),
            clk360  => clk_p,
            rst360  => rst_loc(11),
            lhc_clk => clk_payload(2),
            lhc_rst => rst_payload(2),
            l1a     => l1a_loc(11),
            d(11 downto 0)  => d(55 downto 44), --11 12 13
            d(23 downto 12) => d(75 downto 64),	--16 17 18
            trgg    => trgg_SLR2_regs(0)
        );

    cross_SLR : process(clk_p)
    begin
        if rising_edge(clk_p) then
            trgg_SLR0_regs(trgg_SLR0_regs'high downto 1) <= trgg_SLR0_regs(trgg_SLR0_regs'high - 1 downto 0);
            trgg_SLR2_regs(trgg_SLR2_regs'high downto 1) <= trgg_SLR2_regs(trgg_SLR2_regs'high - 1 downto 0);
        end if;
    end process;
    
    SLR1_local_or : entity work.Trigger_local_or
        port map(
            clk360  => clk_p,
            rst360  => rst_loc(28),
            q(0)    => q(28), --7
            trgg_0  => trgg_SLR0_regs(trgg_SLR0_regs'high),
            trgg_1  => trgg_SLR2_regs(trgg_SLR2_regs'high)
        );

    gpio    <= (others => '0');
    gpio_en <= (others => '0');

end rtl;
