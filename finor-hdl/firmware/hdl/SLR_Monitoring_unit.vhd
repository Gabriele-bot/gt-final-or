library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.emp_data_types.all;
use work.emp_project_decl.all;
use work.ipbus_decode_SLR_Monitoring_unit.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity SLR_Monitoring_unit is
    generic(
        NR_RIGHT_LINKS        : natural := INPUT_R_LINKS_SLR;
        NR_LEFT_LINKS         : natural := INPUT_L_LINKS_SLR;
        BEGIN_LUMI_TOGGLE_BIT : natural := BEGIN_LUMI_SEC_BIT;
        MAX_DELAY             : natural := MAX_DELAY_PDT
    );
    port(
        clk                    : in  std_logic;
        rst                    : in  std_logic;
        ipb_in                 : in  ipb_wbus;
        ipb_out                : out ipb_rbus;
        --====================================================================--
        clk360                 : in  std_logic;
        rst360_r               : in  std_logic;
        rst360_l               : in  std_logic;
        clk40                  : in  std_logic;
        rst40                  : in  std_logic;
        ctrs                   : in  ttc_stuff_t;
        d                      : in  ldata(NR_RIGHT_LINKS + NR_LEFT_LINKS - 1 downto 0); -- data in
        start_of_orbit_o       : out std_logic;
        trigger_o              : out std_logic_vector(N_TRIGG - 1 downto 0);
        trigger_preview_o      : out std_logic_vector(N_TRIGG - 1 downto 0);
        trigger_valid_o        : out std_logic;
        veto_o                 : out std_logic;
        q_algos_o              : out lword;
        q_algos_after_bxmask_o : out lword;
        q_algos_after_prscl_o  : out lword
    );
end entity SLR_Monitoring_unit;

architecture RTL of SLR_Monitoring_unit is

    constant N_CTRL_REGS : integer := 2;
    constant N_STAT_REGS : integer := 1;

    -- fabric signals        
    signal ipb_to_slaves   : ipb_wbus_array(N_SLAVES - 1 downto 0);
    signal ipb_from_slaves : ipb_rbus_array(N_SLAVES - 1 downto 0);

    signal ctrl_reg     : ipb_reg_v(N_CTRL_REGS - 1 downto 0) := ((others => '0'), (others => '1'));
    signal ctrl_reg_stb : ipb_reg_v(N_CTRL_REGS - 1 downto 0) := ((others => '0'), (others => '1'));
    signal stat_reg     : ipb_reg_v(N_STAT_REGS - 1 downto 0);
    signal ctrl_stb     : std_logic_vector(N_CTRL_REGS - 1 downto 0);

    signal rst360 : std_logic;

    signal valid_deser_out : std_logic;

    signal d_reg                   : ldata(NR_RIGHT_LINKS + NR_LEFT_LINKS - 1 downto 0);
    signal d_left_reg, d_right_reg : ldata(1 downto 0);
    signal d_res                   : lword;

    signal algos_int                  : std_logic_vector(N_SLR_ALGOS - 1 downto 0);
    signal algos_after_bxmask_int     : std_logic_vector(N_SLR_ALGOS - 1 downto 0);
    signal algos_after_prscl_int      : std_logic_vector(N_SLR_ALGOS - 1 downto 0);
    signal algos_after_prscl_prvw_int : std_logic_vector(N_SLR_ALGOS - 1 downto 0);

    signal trigger_out         : std_logic_vector(N_TRIGG - 1 downto 0);
    signal trigger_out_preview : std_logic_vector(N_TRIGG - 1 downto 0);
    signal veto_out            : std_logic;

    signal ctrs_first_align : ttc_stuff_array(4 downto 0);

    signal link_mask       : std_logic_vector(NR_RIGHT_LINKS + NR_LEFT_LINKS - 1 downto 0);
    signal rst_align_error : std_logic;
    signal align_error     : std_logic;

    signal ctrs_complete_align  : ttc_stuff_t;
    signal ctrs_align_output    : ttc_stuff_t;
    signal ctrs_internal_output : ttc_stuff_t;

    signal ttc_resync   : std_logic;
    signal delay_resync : std_logic;

    signal links_valids  : std_logic_vector(INPUT_LINKS_SLR - 1 downto 0);
    signal link_valid_OR : std_logic;

    signal bx_nr_360, bx_nr_40 : p2gt_bctr_t                                              := (others => '0');
    signal delay_measured      : std_logic_vector(log2c(MAX_CTRS_DELAY_360) - 1 downto 0) := std_logic_vector(to_unsigned(MAX_CTRS_DELAY_360, log2c(MAX_CTRS_DELAY_360)));
    signal delay_lkd           : std_logic;

    attribute keep : boolean;
    attribute keep of ctrs_first_align : signal is true;

    attribute shreg_extract : string;
    attribute shreg_extract of ctrs_first_align : signal is "no";

begin

    rst360 <= rst360_r or rst360_l;

    fabric_i : entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_slr_monitoring_unit(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    link_valid_gen_l : for i in 0 to NR_RIGHT_LINKS + NR_LEFT_LINKS - 1 generate
        links_valids(i) <= d(i).valid;
    end generate;

    link_valid_OR <= or links_valids;

    process(clk360)
    begin
        if rising_edge(clk360) then
            d_reg <= d;
        end if;
    end process;

    CSR_regs : entity work.ipbus_ctrlreg_cdc_v
        generic map(
            N_CTRL         => N_CTRL_REGS,
            N_STAT         => N_STAT_REGS,
            DEST_SYNC_FF   => 5,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CSR),
            ipb_out => ipb_from_slaves(N_SLV_CSR),
            slv_clk => clk360,
            d       => stat_reg,
            q       => ctrl_reg,
            qmask   => open,
            stb     => ctrl_stb
        );

    strobe_loop : process(clk)
    begin
        if rising_edge(clk) then
            for i in N_CTRL_REGS - 1 downto 0 loop
                if ctrl_stb(i) = '1' then
                    ctrl_reg_stb(i) <= ctrl_reg(i);
                end if;
            end loop;
        end if;
    end process;

    link_mask       <= ctrl_reg_stb(0)(NR_RIGHT_LINKS + NR_LEFT_LINKS - 1 downto 0);
    rst_align_error <= ctrl_reg(1)(0) and ctrl_stb(1);
    delay_resync    <= ctrl_reg(1)(1) and ctrl_stb(1);

    stat_reg(0)(0)                                       <= align_error;
    stat_reg(0)(log2c(MAX_CTRS_DELAY_360) downto 1)      <= delay_measured;
    stat_reg(0)(31 downto log2c(MAX_CTRS_DELAY_360) + 1) <= (others => '0');

    Right_merge : entity work.Link_merger
        generic map(
            NR_LINKS => NR_RIGHT_LINKS
        )
        port map(
            clk360    => clk360,
            rst360    => rst360_r,
            link_mask => link_mask(NR_RIGHT_LINKS - 1 downto 0),
            d         => d_reg(NR_RIGHT_LINKS - 1 downto 0),
            q         => d_right_reg(0)
        );

    Left_merge : entity work.Link_merger
        generic map(
            NR_LINKS => NR_LEFT_LINKS
        )
        port map(
            clk360    => clk360,
            rst360    => rst360_l,
            link_mask => link_mask(NR_LEFT_LINKS + NR_RIGHT_LINKS - 1 downto NR_RIGHT_LINKS),
            d         => d_reg(NR_LEFT_LINKS + NR_RIGHT_LINKS - 1 downto NR_RIGHT_LINKS),
            q         => d_left_reg(0)
        );

    process(clk360)
    begin
        if rising_edge(clk360) then
            d_left_reg(1)  <= d_left_reg(0);
            d_right_reg(1) <= d_right_reg(0);
        end if;
    end process;

    Last_merge : entity work.Link_merger
        generic map(
            NR_LINKS => 2
        )
        port map(
            clk360    => clk360,
            rst360    => rst360,
            link_mask => (others => '1'),
            d(0)      => d_right_reg(1),
            d(1)      => d_left_reg(1),
            q         => d_res
        );

    deser_i : entity work.Link_deserializer
        generic map(
            OUT_REG => DESER_OUT_REG
        )
        port map(
            clk360       => clk360,
            rst360       => rst360,
            clk40        => clk40,
            rst40        => rst40,
            lane_data_in => d_res,
            rst_err      => rst_align_error,
            align_err_o  => align_error,
            demux_data_o => algos_int,
            valid_out    => valid_deser_out
        );

    -----------------------------------------------------------------------------------
    ---------------COUNTERS ALIGN------------------------------------------------------
    -----------------------------------------------------------------------------------

    ctrs_first_align(0) <= ctrs;
    CTRS_merge_align_p : process(clk360)
    begin
        if rising_edge(clk360) then
            ctrs_first_align(ctrs_first_align'high downto 1) <= ctrs_first_align(ctrs_first_align'high - 1 downto 0);
        end if;
    end process CTRS_merge_align_p;

    BX_producer_i : entity work.CTRS_BX_nr_producer
        port map(
            clk360         => clk360,
            rst360         => rst360,
            clk40          => clk40,
            rst40          => rst40,
            valid          => d_res.valid,
            last           => d_res.last,
            start          => d_res.start,
            start_of_orbit => d_res.start_of_orbit,
            bx_nr_40       => bx_nr_40,
            bx_nr_360      => bx_nr_360
        );

    BX_delay_i : entity work.CTRS_delay_producer
        generic map(
            MAX_LATENCY_360 => MAX_CTRS_DELAY_360
        )
        port map(
            clk360       => clk360,
            rst360       => rst360,
            clk40        => clk40,
            rst40        => rst40,
            ref_bx_nr    => bx_nr_360,
            ctrs_in      => ctrs_first_align(ctrs_first_align'high),
            delay_resync => ttc_resync or delay_resync,
            delay_lkd    => delay_lkd,
            delay_val    => delay_measured
        );

    CTRS_align_i : entity work.CTRS_fixed_alignment
        generic map(
            MAX_LATENCY_360 => MAX_CTRS_DELAY_360,
            DELAY_OFFSET    => 0
        )
        port map(
            clk360         => clk360,
            rst360         => rst360,
            clk40          => clk40,
            rst40          => rst40,
            ctrs_delay_lkd => delay_lkd,
            ctrs_delay_val => delay_measured,
            ctrs_in        => ctrs_first_align(ctrs_first_align'high),
            ctrs_out       => ctrs_complete_align
        );

    CTRS_align_output_i : entity work.CTRS_fixed_alignment
        generic map(
            MAX_LATENCY_360 => MAX_CTRS_DELAY_360,
            DELAY_OFFSET    => 9        -- deserializer
        )
        port map(
            clk360         => clk360,
            rst360         => rst360,
            clk40          => clk40,
            rst40          => rst40,
            ctrs_delay_lkd => delay_lkd,
            ctrs_delay_val => delay_measured,
            ctrs_in        => ctrs_first_align(ctrs_first_align'high),
            ctrs_out       => ctrs_align_output
        );

    monitoring_module : entity work.monitoring_module
        generic map(
            NR_ALGOS              => N_SLR_ALGOS,
            NR_TRIGGERS           => N_TRIGG,
            PRESCALE_FACTOR_INIT  => X"00000064", --1.00,
            BEGIN_LUMI_TOGGLE_BIT => BEGIN_LUMI_TOGGLE_BIT,
            MAX_DELAY             => MAX_DELAY
        )
        port map(
            clk                     => clk,
            rst                     => rst,
            ipb_in                  => ipb_to_slaves(N_SLV_MONITORING_MODULE),
            ipb_out                 => ipb_from_slaves(N_SLV_MONITORING_MODULE),
            clk360                  => clk360,
            rst360                  => rst360,
            clk40                   => clk40,
            rst40                   => rst40,
            ctrs                    => ctrs_complete_align,
            algos_in                => algos_int,
            valid_algos_in          => valid_deser_out,
            algos_after_bxmask_o    => algos_after_bxmask_int,
            algos_after_prescaler_o => algos_after_prscl_int,
            trigger_o               => trigger_out,
            trigger_preview_o       => trigger_out_preview,
            valid_trigger_o         => trigger_valid_o,
            veto_o                  => veto_out,
            start_of_orbit_o        => start_of_orbit_o,
            resync_o                => ttc_resync
        );

    deser_reg_out_g : if DESER_OUT_REG generate
        process(clk40)
        begin
            if rising_edge(clk40) then
                ctrs_internal_output <= ctrs_align_output;
            end if;
        end process;
    else generate
        ctrs_internal_output <= ctrs_align_output;
    end generate;

    output_links_data_i : entity work.algobits_out
        port map(
            clk360               => clk360,
            rst360               => rst360,
            clk40                => clk40,
            rst40                => rst40,
            ctrs                 => ctrs_internal_output,
            algos_in             => algos_int,
            algos_after_bxmask   => algos_after_bxmask_int,
            algos_after_prscl    => algos_after_prscl_int,
            algos_valid          => valid_deser_out,
            q_algos              => q_algos_o,
            q_algos_after_bxmask => q_algos_after_bxmask_o,
            q_algos_after_prscl  => q_algos_after_prscl_o
        );
     
    trigger_o         <= trigger_out;
    trigger_preview_o <= trigger_out_preview;
    veto_o            <= veto_out;

end architecture RTL;
