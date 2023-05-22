-- emp_datapath_sim
--
-- Datapath test moduele, still under development
--
-- Gabriele Bortolato, December 2022
-- 
-- heavily inspired by the corresponding emp code from
-- Dave Newbold, February 2014
-- Alessandro Thea, March 2018

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.emp_ttc_decl.all;
--No support for datapath info yet, only read/write from/to pattern files
--use work.ipbus_decode_emp_datapath.all;
use work.drp_decl.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;
use work.emp_framework_decl.all;
use work.emp_device_decl.all;
--use work.emp_datapath_utils.all;

--! Using Testbench declaration
use work.tb_decl;

entity emp_datapath_sim is
    generic(
        sourcefile : string  := tb_decl.SOURCE_FILE;
        sinkfile   : string  := tb_decl.SINK_FILE;
        striphdr   : boolean := tb_decl.STRIP_HEADER;
        inserthdr  : boolean := tb_decl.INSERT_HEADER;
        playlen    : natural := tb_decl.PLAYBACK_LENGTH;
        playoffset : natural := tb_decl.PLAYBACK_OFFSET;
        playloop   : boolean := tb_decl.PLAYBACK_LOOP;
        caplen     : natural := tb_decl.CAPTURE_LENGTH;
        capoffset  : natural := tb_decl.CAPTURE_OFFSET;
        dryrun     : boolean := false;
        debug      : boolean := false
    );
    port(
        clk       : in  std_logic;      -- ipbus clock, rst, bus
        rst       : in  std_logic;
        ipb_in    : in  ipb_wbus;
        ipb_out   : out ipb_rbus;
        clk125    : in  std_logic;
        clk40     : in  std_logic;
        clk_p     : in  std_logic;      -- parallel data clock & rst
        rst_p     : in  std_logic;
        ttc_cmd   : in  ttc_cmd_t;      -- TTC command (clk40 domain)
        ttc_l1a   : in  std_logic;      -- TTC L1A (clk40 domain)
        lock      : out std_logic;      -- lock flag for distributed bunch counters
        ctrs_out  : out ttc_stuff_array(N_REGION - 1 downto 0); -- TTC counters for local logic
        rst_out   : out std_logic_vector(N_REGION - 1 downto 0); -- Resets for local logic;
        clken_out : out std_logic_vector(N_REGION - 1 downto 0); -- Clock enables for local logic;
        refclkp   : in  std_logic_vector(N_REFCLK - 1 downto 0); -- MGT refclks & IO
        refclkn   : in  std_logic_vector(N_REFCLK - 1 downto 0);
        clkmon    : out std_logic_vector(3 downto 0); -- clock frequency monitoring outputs
        d         : in  ldata(N_REGION * 4 - 1 downto 0); -- parallel data from payload
        q         : out ldata(N_REGION * 4 - 1 downto 0) -- parallel data to payload
    );

end entity emp_datapath_sim;

architecture RTL of emp_datapath_sim is

    --signal ipbw  : ipb_wbus_array(N_SLAVES - 1 downto 0);
    --signal ipbr  : ipb_rbus_array(N_SLAVES - 1 downto 0);
    --signal ipbdc : ipbdc_bus_array(N_REGION downto 0);

    --signal ctrl, ctrl_rx_enable : ipb_reg_v(0 downto 0);

    signal ttc_cmd_i, ttc_cmd_i2 : ttc_cmd_t;
    attribute keep               : string;
    attribute keep of ttc_cmd_i : signal is "true";

    signal rst_chain_a, lock_chain_a, rx_enable_chain_a : std_logic_vector(N_REGION downto 0);
    signal ttc_chain_a                                  : ttc_cmd_array(N_REGION downto 0);
    --signal l1a_chain_a               : std_logic_vector(N_REGION downto 0);
    --signal tmt_chain_a               : tmt_sync_array(N_REGION downto 0);
    --signal cap_chain_a               : daq_cap_bus_array(N_REGION downto 0);
    --signal daq_chain_a               : daq_bus_array(N_REGION downto 0);

    signal rst_chain_b, lock_chain_b, rx_enable_chain_b : std_logic_vector(N_REGION downto 0);
    signal ttc_chain_b                                  : ttc_cmd_array(N_REGION downto 0);
    --signal l1a_chain_b               : std_logic_vector(N_REGION downto 0);
    --signal tmt_chain_b               : tmt_sync_array(N_REGION downto 0);
    --signal cap_chain_b               : daq_cap_bus_array(N_REGION downto 0);
    --signal daq_chain_b               : daq_bus_array(N_REGION downto 0);

    --signal dbus_cross : daq_bus;

    signal refclk, refclk_odiv, refclk_buf : std_logic_vector(N_REFCLK - 1 downto 0);
    signal refclk_mon, refclk_mon_d        : std_logic_vector(N_REFCLK - 1 downto 0);
    signal rxclk_mon, txclk_mon            : std_logic_vector(31 downto 0); -- Match range of integer sel
    signal sel                             : integer range 0 to 31;
    --signal ctrs                            : ttc_stuff_array(N_REGION - 1 downto 0);
    signal rx_enable                       : std_logic;

    signal ctrs_int  : ttc_stuff_array(N_REGION - 1 downto 0); -- TTC counters for local logic
    signal rst_int   : std_logic_vector(N_REGION - 1 downto 0); -- Resets for local logic;
    signal clken_int : std_logic_vector(N_REGION - 1 downto 0); -- Clock enables for local logic;

    signal lock_i : std_logic;

    -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- LINK SIGNALS
    signal d_int : ldata(N_REGION * 4 - 1 downto 0) := (others => LWORD_NULL); -- parallel data from payload
    signal q_int : ldata(N_REGION * 4 - 1 downto 0) := (others => LWORD_NULL); -- parallel data to payload
    -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    --signal tmt_sync_i, tmt_sync                                                : tmt_sync_t;
    signal rst_i, bctr_lock, bc0, oc0, go, bmax : std_logic;
    signal rst_p_del_array                      : std_logic_vector(9 downto 0) := (others => '0');
    signal clr                                  : std_logic;
    --signal cap_bus_i, cap_bus                                                : daq_cap_bus;
    signal pctr                                 : pctr_t;
    signal bctr                                 : bctr_t;
    signal octr                                 : octr_t;

begin

    ipb_out.ipb_rdata <= (others => '0');
    ipb_out.ipb_ack   <= ipb_in.ipb_strobe;
    ipb_out.ipb_err   <= '0';

    rst_p_del_array(0) <= rst_p;
    process(clk_p)
    begin
        if rising_edge(clk_p) then
            rst_p_del_array(rst_p_del_array'high downto 1) <= rst_p_del_array(rst_p_del_array'high - 1 downto 0);
        end if;
    end process;

    clr <= rst_p_del_array(2) or rst_p;

    ------------------------------------------
    -- Bunch counter
    bunch : entity work.bunch_ctr
        generic map(
            CLOCK_RATIO     => CLOCK_RATIO,
            CLK_DIV         => CLOCK_RATIO,
            CTR_WIDTH       => bctr_t'length,
            PCTR_WIDTH      => pctr_t'length,
            OCTR_WIDTH      => octr'length,
            LHC_BUNCH_COUNT => LHC_BUNCH_COUNT,
            BC0_BX          => TTC_DEL + 4 -- Extra two for two clk40 registers of TTC commands in emp_ttc
            -- (from TCDS2 FW to ttc_cmd_dist port), then two more for pair
            -- of clk40 registers in emp_datapath
        )
        port map(
            clk  => clk_p,
            rst  => rst_p_del_array(5),
            clr  => '0',
            bc0  => bc0,
            oc0  => oc0,
            bctr => bctr,
            pctr => pctr,
            bmax => bmax,
            octr => octr,
            lock => bctr_lock
        );

    ------------------------------------------
    -- BGOs
    bc0 <= '1' when ttc_cmd = TTC_BCMD_BC0 else '0';
    oc0 <= '1' when ttc_cmd = TTC_BCMD_OC0 else '0';
    --resync_i <= '1' when ttc_cmd = TTC_BCMD_RESYNC    else '0';
    --go       <= '1' when ttc_cmd = TTC_BCMD_TEST_SYNC else '0';

    source : entity work.EMPCaptureFileReader
        generic map(
            gFileName       => sourcefile,
            gPlaybackLength => playlen,
            gPlaybackOffset => playoffset,
            gPlaybackLoop   => playloop,
            gStripHeader    => striphdr,
            gDebugMessages  => debug
        )
        port map(
            clk      => clk_p,
            rst      => rst_p_del_array(5),
            pctr     => pctr,
            bctr     => bctr,
            LinkData => q_int
        );

    sink : entity work.EMPCaptureFileWriter
        generic map(
            gFileName      => sinkfile,
            gCaptureOffset => (capoffset + tb_decl.WAIT_CYCLES_AT_START),
            gCaptureLength => caplen,
            gInsertHeader  => inserthdr,
            gDebugMessages => debug
        )
        port map(
            clk      => clk_p,
            rst      => rst_p_del_array(5),
            pctr     => pctr,
            bctr     => bctr,
            LinkData => d_int
        );

    sgen : for i in 0 to N_REGION - 1 generate
    begin
        -- Outputs to local logic 
        rst_out(i)          <= rst_p_del_array(5);
        ctrs_out(i).ttc_cmd <= ttc_cmd;
        ctrs_out(i).l1a     <= ttc_l1a; --l1a;
        ctrs_out(i).bctr    <= bctr;
        ctrs_out(i).pctr    <= pctr;
    end generate;

    lock      <= bctr_lock;             --TODO check
    clken_out <= (others => '1');
    clkmon    <= (others => '0');
    d_int     <= d;
    q         <= q_int;

end architecture RTL;
