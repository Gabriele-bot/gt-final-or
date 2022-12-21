--! Using the IEEE Library
library IEEE;
--! Using STD_LOGIC
use IEEE.STD_LOGIC_1164.all;
--! Using NUMERIC TYPES
use IEEE.NUMERIC_STD.all;
use ieee.math_real.all;

--! Using the EMP data-types
use work.emp_data_types.all;

--! Using slink data types
use work.emp_slink_types.all;

--! Using TTC data-types
use work.emp_ttc_decl.all;

--! Using EMP device declaration
use work.emp_device_decl.all;

--! Using the testbench helper package
use work.emp_capture_tools.all;
use work.emp_testbench_helpers.all;
--
--! Using ipbus definitions
--use work.ipbus.all;

--! Project declaration
use work.emp_project_decl.all;

--! Using Testbench declaration
use work.tb_decl;

use work.ipbus.all;

-- sim decoders
use work.ipbus_decode_sim.all;

use work.P2GT_finor_pkg.all;



--!
--! @brief      An entity providing a TestBench
--! @details    Detailed description
--!
entity top is
    generic(
        UNIX_TIME             : std_logic_vector(31 downto 0) := X"00000000";
        GIT_REPOS_NAME        : std_logic_vector              := X"";
        GIT_REPOS_SHA         : std_logic_vector              := X"";
        GIT_REPOS_CLEAN       : std_logic_vector              := X"";
        GIT_REPOS_REF         : std_logic_vector              := X"";
        GITLAB_CI_PROJECT_ID  : integer                       := 0;
        GITLAB_CI_PIPELINE_ID : integer                       := 0;
        GITLAB_CI_JOB_ID      : integer                       := 0;
        ---------------------------------------------------------------------
        --TB values
        ---------------------------------------------------------------------
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
end top;

--! @brief Architecture definition for entity TestBench
--! @details Detailed description
architecture rtl of top is

    -- IPBus signals
    signal ipb_clk, ipb_rst : std_logic;

    signal ipb_w : ipb_wbus;
    signal ipb_r : ipb_rbus;

    signal ipb_w_array : ipb_wbus_array(N_SLAVES - 1 downto 0);
    signal ipb_r_array : ipb_rbus_array(N_SLAVES - 1 downto 0);

    -- Clock domain reset outputs
    signal clk125   : std_logic;
    signal clk40    : std_logic;
    signal rst40    : std_logic;
    signal clk_p    : std_logic;
    signal rst_p    : std_logic;
    signal clks_aux : std_logic_vector(2 downto 0);
    signal rsts_aux : std_logic_vector(2 downto 0);

    -- TTC signals  
    signal ttc_l1a, ttc_l1a_dist, dist_lock, oc_flag, ec_flag : std_logic;
    signal ttc_cmd, ttc_cmd_dist                              : ttc_cmd_t;
    signal bunch_ctr                                          : bctr_t;
    signal evt_ctr, orb_ctr                                   : eoctr_t;

    -- Others
    signal soft_rst : std_logic;

    -- Datapath signals
    signal payload_d, payload_q : ldata(N_REGION * 4 - 1 downto 0);
    signal clkmon               : std_logic_vector(3 downto 0);
    signal ctrs                 : ttc_stuff_array(N_REGION - 1 downto 0);
    signal rst_loc, clken_loc   : std_logic_vector(N_REGION - 1 downto 0);



begin

    -- Infrastructure

    infra : entity work.sim_udp_infra
        port map(
            soft_rst => soft_rst,
            ipb_clk  => ipb_clk,
            ipb_rst  => ipb_rst,
            ipb_in   => ipb_r,
            ipb_out  => ipb_w,
            clk125   => clk125
        );

    -- ipbus fabric selector

    fabric : entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH)
        port map(
            ipb_in          => ipb_w,
            ipb_out         => ipb_r,
            sel             => ipbus_sel_sim(ipb_w.ipb_addr),
            ipb_to_slaves   => ipb_w_array,
            ipb_from_slaves => ipb_r_array
        );


    -- info block (constant registers containing version numbers, build info, etc)
    info : entity work.emp_info
        generic map (
            UNIX_TIME             => UNIX_TIME,
            GIT_REPOS_NAME        => GIT_REPOS_NAME,
            GIT_REPOS_SHA         => GIT_REPOS_SHA,
            GIT_REPOS_CLEAN       => GIT_REPOS_CLEAN,
            GIT_REPOS_REF         => GIT_REPOS_REF,
            GITLAB_CI_PROJECT_ID  => GITLAB_CI_PROJECT_ID,
            GITLAB_CI_PIPELINE_ID => GITLAB_CI_PIPELINE_ID,
            GITLAB_CI_JOB_ID      => GITLAB_CI_JOB_ID
        )
        port map(
            clk     => ipb_clk,
            rst     => ipb_rst,
            ipb_in  => ipb_w_array(N_SLV_INFO),
            ipb_out => ipb_r_array(N_SLV_INFO)
        );

    ctrl : entity work.emp_ctrl
        port map (
            clk      => ipb_clk,
            rst      => ipb_rst,
            ipb_in   => ipb_w_array(N_SLV_CTRL),
            ipb_out  => ipb_r_array(N_SLV_CTRL),
            soft_rst => soft_rst,
            debug    => (others => '0')
        );

    -- TTC block
    ttc : entity work.ttc_sim
        port map(
            clk_ipb      => ipb_clk,
            rst_ipb      => ipb_rst,
            ipb_in       => ipb_w_array(N_SLV_TTC),
            ipb_out      => ipb_r_array(N_SLV_TTC),
            clk40        => clk40,
            rst40        => rst40,
            clk_p        => clk_p,
            rst_p        => rst_p,
            clks_aux     => clks_aux,
            rsts_aux     => rsts_aux,
            ttc_cmd      => ttc_cmd,
            ttc_cmd_dist => ttc_cmd_dist,
            ttc_l1a      => ttc_l1a,
            ttc_l1a_dist => ttc_l1a_dist,
            dist_lock    => dist_lock,
            bunch_ctr    => bunch_ctr,
            evt_ctr      => (others => '0'),
            orb_ctr      => open,
            oc_flag      => oc_flag,
            ec_flag      => ec_flag,
            monclk       => clkmon
        );

    -- Datapath block
    datapath : entity work.emp_datapath_sim
        generic map(
            sourcefile => sourcefile,
            sinkfile   => sinkfile,
            striphdr   => striphdr,
            inserthdr  => inserthdr,
            playlen    => playlen,
            playoffset => playoffset,
            playloop   => playloop,
            caplen     => caplen,
            capoffset  => capoffset,
            dryrun     => dryrun,
            debug      => debug
        )
        port map(
            clk         => ipb_clk,
            rst         => ipb_rst,
            ipb_in      => ipb_w_array(N_SLV_DATAPATH),
            ipb_out     => ipb_r_array(N_SLV_DATAPATH),
            clk125      => clk125,
            clk40       => clk40,
            clk_p       => clk_p,
            rst_p       => rst_p,
            ttc_cmd     => ttc_cmd_dist,
            ttc_l1a     => ttc_l1a_dist,
            lock        => dist_lock,
            ctrs_out    => ctrs,
            rst_out     => rst_loc,
            clken_out   => clken_loc,
            refclkp     => (others => '0'),
            refclkn     => (others => '0'),
            clkmon      => clkmon,
            q           => payload_d,
            d           => payload_q
        );

    -- And finally, the payload
    payload : entity work.emp_payload
        generic map(
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_SEC_BIT_SIM
        )
        port map(
            clk         => ipb_clk,
            rst         => ipb_rst,
            ipb_in      => ipb_w_array(N_SLV_PAYLOAD),
            ipb_out     => ipb_r_array(N_SLV_PAYLOAD),
            clk40       => clk40,
            clk_payload => clks_aux,
            rst_payload => rsts_aux,
            clk_p       => clk_p,
            rst_loc     => rst_loc,
            clken_loc   => clken_loc,
            ctrs        => ctrs,
            bc0         => open,
            d           => payload_d,
            q           => payload_q,
            gpio        => open,
            gpio_en     => open,
            slink_q     => open,
            backpressure => (others => '0')
        );

end rtl;


