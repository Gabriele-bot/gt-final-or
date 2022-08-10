library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_m_module.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;


--use work.P2GT_monitor_pkg.all;
--use work.pre_scaler_pkg.all;
--use work.Finor_pkg.all;
use work.P2GT_finor_pkg.all;

use work.math_pkg.all;



entity m_module is
    generic(
        NR_ALGOS             : natural;
        PRESCALE_FACTOR_INIT : std_logic_vector(31 DOWNTO 0) := X"00000064"; --1.00
        MAX_DELAY            : natural := 127
    );
    port(
        clk                 : in std_logic;
        rst                 : in std_logic;
        ipb_in              : in ipb_wbus;
        ipb_out             : out ipb_rbus;
        -- ==========================================================================
        lhc_clk     : in  std_logic;
        lhc_rst     : in  std_logic;

        ctrs                     : in  ttc_stuff_t;

        algos_in                 : in  std_logic_vector(NR_ALGOS-1 downto 0);
        algos_after_prescaler_o  : out std_logic_vector(NR_ALGOS-1 downto 0);
        trgg_o                   : out std_logic_vector(N_TRIGG-1  downto 0)

    );
end m_module;


architecture rtl of m_module is


    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

    --algos signal
    signal algos_after_bxmask            : std_logic_vector(NR_ALGOS-1 downto 0) := (others => '0');
    signal algos_delayed                 : std_logic_vector(NR_ALGOS-1 downto 0) := (others => '0');
    signal algos_after_prescaler         : std_logic_vector(NR_ALGOS-1 downto 0) := (others => '0');
    signal algos_after_prescaler_preview : std_logic_vector(NR_ALGOS-1 downto 0) := (others => '0');

    -- prescale factor ipb regs
    signal prscl_fct      : ipb_reg_v(NR_ALGOS - 1 downto 0) := (others => PRESCALE_FACTOR_INIT);
    signal prscl_fct_prvw : ipb_reg_v(NR_ALGOS - 1 downto 0) := (others => PRESCALE_FACTOR_INIT);

    -- rate counter ipb regs
    signal rate_cnt_before_prescaler        : ipb_reg_v(NR_ALGOS - 1 downto 0);
    signal rate_cnt_after_prescaler         : ipb_reg_v(NR_ALGOS - 1 downto 0);
    signal rate_cnt_after_prescaler_preview : ipb_reg_v(NR_ALGOS - 1 downto 0);
    signal rate_cnt_post_dead_time          : ipb_reg_v(NR_ALGOS - 1 downto 0);

    signal masks_ipbus_regs      : ipb_reg_v(NR_ALGOS/32*N_TRIGG - 1 downto 0) := (others => (others => '1'));
    signal masks                 : mask_arr := (others => (others => '1'));

    signal request_factor_update : std_logic;
    signal ctrl_reg : ipb_reg_v(0 downto 0);
    signal stat_reg : ipb_reg_v(0 downto 0);

    -- counters and bgos signals
    signal bc0, oc0, ec0               : std_logic := '0';
    signal begin_lumi_per              : std_logic;
    signal begin_lumi_per_del1         : std_logic;
    signal l1a_latency_delay           : std_logic_vector(log2c(MAX_DELAY)-1 downto 0);


    type state_t is (idle, start, increment);
    signal state, state_mask : state_t := idle;

    signal q_prscl_fct, q_prscl_fct_prvw : std_logic_vector(31 downto 0);
    signal d_rate_cnt_before_prescaler, d_rate_cnt_after_prescaler       : std_logic_vector(31 downto 0);
    signal d_rate_cnt_after_prescaler_preview, d_rate_cnt_post_dead_time : std_logic_vector(31 downto 0);
    signal q_mask: std_logic_vector(31 downto 0);
    signal addr       : unsigned(log2c(NR_ALGOS)-1 downto 0);
    signal addr_w     : unsigned(log2c(NR_ALGOS)-1 downto 0) := (others => '0');
    signal addr_mask   : unsigned(log2c(NR_ALGOS/32*N_TRIGG)-1 downto 0);
    signal addr_mask_w : unsigned(log2c(NR_ALGOS/32*N_TRIGG)-1 downto 0) := (others => '0');
    signal mask_index : unsigned(log2c(N_TRIGG)-1 downto 0);
    signal we, we_mask    : std_logic;
    signal ready : std_logic;

    signal trigger_out             : std_logic_vector(N_TRIGG-1 downto 0);

begin


    -- TODO check delay

    -- rate counters are updated with begin_lumi_per_del1
    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            begin_lumi_per_del1 <= begin_lumi_per;
        end if;
    end process;


    -- process to write into ipbus-RAMs
    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            case state is
                when idle =>
                    addr   <= (others => '0');
                    we     <= '0';
                    if begin_lumi_per_del1 = '1' then
                        state <= start;
                    end if;
                when start =>
                    addr  <= (others => '0');
                    we    <= '1';
                    -- TODO check in hardware what happens to the first reg
                    d_rate_cnt_before_prescaler        <= rate_cnt_before_prescaler(0);
                    d_rate_cnt_after_prescaler         <= rate_cnt_after_prescaler(0);
                    d_rate_cnt_after_prescaler_preview <= rate_cnt_after_prescaler_preview(0);
                    d_rate_cnt_post_dead_time          <= rate_cnt_post_dead_time(0);
                    state <= increment;
                when increment =>
                    addr <= addr + 1;
                    we   <= '1';
                    d_rate_cnt_before_prescaler        <= rate_cnt_before_prescaler(to_integer(addr + 1));
                    d_rate_cnt_after_prescaler         <= rate_cnt_after_prescaler(to_integer(addr + 1));
                    d_rate_cnt_after_prescaler_preview <= rate_cnt_after_prescaler_preview(to_integer(addr + 1));
                    d_rate_cnt_post_dead_time          <= rate_cnt_post_dead_time(to_integer(addr + 1));
                    if addr >= NR_ALGOS-2 then --(2 is due to latency)
                        state <= idle;
                    end if;
            end case;
        end if;
    end process;

    -- process to write into ipbus-RAMs
    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            case state_mask is
                when idle =>
                    addr_mask   <= (others => '0');
                    we_mask     <= '0';
                    if begin_lumi_per_del1 = '1' then
                        state_mask <= start;
                    end if;
                when start =>
                    addr_mask  <= (others => '0');
                    we_mask    <= '1';
                    -- TODO check in hardware what happens to the first reg
                    state_mask <= increment;
                when increment =>
                    addr_mask <= addr_mask + 1;
                    we_mask   <= '1';
                    if addr_mask >= NR_ALGOS/32*N_TRIGG-2 then --(2 is due to latency)
                        state_mask <= idle;
                    end if;
            end case;
        end if;
    end process;    

    -- process to read from ipbus-RAMs
    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            -----------Prescalers----------------------------
            prscl_fct(to_integer(addr_w))      <= q_prscl_fct;
            prscl_fct_prvw(to_integer(addr_w)) <= q_prscl_fct_prvw;
            -----------Trigger masks---------------------------------
            masks_ipbus_regs(to_integer(addr_mask_w))      <= q_mask;
            
            -- delayed index for the regs
            addr_w         <= addr;
            addr_mask_w    <= addr_mask;
        end if;
    end process;



    fabric_i: entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_m_module(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    ----------------------------------------------------------------------------------
    ---------------PRE-SCALE REGISTERS------------------------------------------------
    ----------------------------------------------------------------------------------

    prscl_fct_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => PRESCALE_FACTOR_INIT,
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_PRESCALE_FACTOR),
            ipb_out => ipb_from_slaves(N_SLV_PRESCALE_FACTOR),
            rclk    => lhc_clk,
            we      => '0',
            d       => (others => '0'),
            q       => q_prscl_fct,
            addr    => std_logic_vector(addr)
        );

    ----------------------------------------------------------------------------------
    ---------------PRE-SCALE PREVIEW REGISTERS----------------------------------------
    ----------------------------------------------------------------------------------

    prscl_fct_prvw_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => PRESCALE_FACTOR_INIT,
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_PRESCALE_FACTOR_PRVW),
            ipb_out => ipb_from_slaves(N_SLV_PRESCALE_FACTOR_PRVW),
            rclk    => lhc_clk,
            we      => '0',
            d       => (others => '0'),
            q       => q_prscl_fct_prvw,
            addr    => std_logic_vector(addr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER BEFORE PRE-SCALE REGISTERS----------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_before_prsc_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_BEFORE_PRSC),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_BEFORE_PRSC),
            rclk    => lhc_clk,
            we      => we,
            d       => d_rate_cnt_before_prescaler,
            q       => open,
            addr    => std_logic_vector(addr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER AFTER PRE-SCALE REGISTERS-----------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_after_prsc_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_AFTER_PRSC),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_AFTER_PRSC),
            rclk    => lhc_clk,
            we      => we,
            d       => d_rate_cnt_after_prescaler,
            q       => open,
            addr    => std_logic_vector(addr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER AFTER PRE-SCALE PREVIEW REGISTERS---------------------
    ----------------------------------------------------------------------------------

    rate_cnt_after_prsc_prvw_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_AFTER_PRSC_PRVW),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_AFTER_PRSC_PRVW),
            rclk    => lhc_clk,
            we      => we,
            d       => d_rate_cnt_after_prescaler_preview,
            q       => open,
            addr    => std_logic_vector(addr)
        );

    ----------------------------------------------------------------------------------
    ---------------RATE COUNTER POST DEAD-TIME REGISTERS------------------------------
    ----------------------------------------------------------------------------------

    rate_cnt_post_dead_time_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(NR_ALGOS),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_CNT_RATE_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_PDT),
            rclk    => lhc_clk,
            we      => we,
            d       => d_rate_cnt_post_dead_time,
            q       => open,
            addr    => std_logic_vector(addr)
        );

    blp_regs : entity work.ipbus_ctrlreg_v
        generic map(
            N_CTRL     => 1,
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
            stb       => open
        );

    --xpm_cdc_begin_lumi_per : xpm_cdc_single
    --    generic map (
    --        DEST_SYNC_FF => 3,
    --        INIT_SYNC_FF => 0,
    --        SIM_ASSERT_CHK => 0,
    --        SRC_INPUT_REG => 1
    --    )
    --    port map (
    --        dest_out => begin_lumi_per,
    --        dest_clk => lhc_clk,
    --        src_clk  => clk,
    --        src_in   => ctrl_reg(0)(0)
    --    );


    xpm_cdc_pulse_inst : xpm_cdc_pulse
        generic map (
            DEST_SYNC_FF   => 3, -- DECIMAL; range: 2-10
            INIT_SYNC_FF   => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            REG_OUTPUT     => 1, -- DECIMAL; 0=disable registered output, 1=enable registered output
            RST_USED       => 0, -- DECIMAL; 0=no reset, 1=implement reset
            SIM_ASSERT_CHK => 0  -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        )
        port map (
            --  LHC clock domain (40MHz)
            dest_pulse => open,
            dest_clk   => lhc_clk,
            dest_rst   => '0',
            -- ipbus clock domain (125MHz)
            src_clk    => clk,
            src_pulse  => ctrl_reg(0)(0),
            src_rst    => rst
        );
    -- End of xpm_cdc_pulse_inst instantiatio

    xpm_cdc_request_factor_update : xpm_cdc_single
        generic map (
            DEST_SYNC_FF => 3,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map (
            dest_out => request_factor_update,
            dest_clk => lhc_clk,
            src_clk  => clk,
            src_in   => ctrl_reg(0)(1)
        );

    xpm_cdc_l1a_latency_delay : xpm_cdc_array_single
        generic map (
            DEST_SYNC_FF => 3,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1,
            WIDTH          => log2c(MAX_DELAY)
        )
        port map (
            dest_out => l1a_latency_delay,
            dest_clk => lhc_clk,
            src_clk  => clk,
            src_in   => ctrl_reg(0)(log2c(MAX_DELAY) + 1 downto 2)
        );

    ready <= not we;

    xpm_cdc_ready : xpm_cdc_single
        generic map (
            DEST_SYNC_FF => 3,
            INIT_SYNC_FF => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG => 1
        )
        port map (
            dest_out => stat_reg(0)(0),
            dest_clk => clk,
            src_clk  => lhc_clk,
            src_in   => ready
        );


    --begin_lumi_per        <= ctrl_reg(0)(0);
    --request_factor_update <= ctrl_reg(0)(1);
    --l1a_latency_delay     <= ctrl_reg(0)(log2c(MAX_DELAY) + 1 downto 2);
    --stat_reg(0)(0)        <= ready;

    ----------------------------------------------------------------------------------
    ---------------TRIGGER MASKS REGISTERS--------------------------------------------
    ----------------------------------------------------------------------------------

    masks_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"ffffffff",
            ADDR_WIDTH => log2c(NR_ALGOS/32*N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves(N_SLV_TRGG_MASK),
            ipb_out => ipb_from_slaves(N_SLV_TRGG_MASK),
            rclk    => lhc_clk,
            we      => '0',
            d       => (others => '0'),
            q       => q_mask,
            addr    => std_logic_vector(addr_mask)
        );

    --TODO Add a request update mask as we did for the prescalers
    mask_l : for i in N_TRIGG - 1 downto 0 generate
        process(lhc_clk)
        begin
            if rising_edge(lhc_clk) then
                if (we_mask = '0') then
                    masks(i) <= (masks_ipbus_regs(i*18+17), masks_ipbus_regs(i*18+16),
                                 masks_ipbus_regs(i*18+15), masks_ipbus_regs(i*18+14),
                                 masks_ipbus_regs(i*18+13), masks_ipbus_regs(i*18+12),
                                 masks_ipbus_regs(i*18+11), masks_ipbus_regs(i*18+10),
                                 masks_ipbus_regs(i*18+9) , masks_ipbus_regs(i*18+8) ,
                                 masks_ipbus_regs(i*18+7) , masks_ipbus_regs(i*18+6) ,
                                 masks_ipbus_regs(i*18+5) , masks_ipbus_regs(i*18+4) ,
                                 masks_ipbus_regs(i*18+3) , masks_ipbus_regs(i*18+2) ,
                                 masks_ipbus_regs(i*18+1) , masks_ipbus_regs(i*18+0) );
                end if;
            end if;
        end process;
    end generate;
    -- TODO Make it interchangable

    delay_element_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => NR_ALGOS,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk    => lhc_clk,
            rst    => lhc_rst,
            data_i => algos_in,
            data_o => algos_delayed,
            delay  => l1a_latency_delay
        );

    ----------------------------------------------------------------------------------
    ---------------COUTER MODULE------------------------------------------------------
    ----------------------------------------------------------------------------------

    Counters_i : entity work.Counter_module
            generic map (
                BEGIN_LUMI_BIT => 18
            )
            port map (
                lhc_clk        => lhc_clk,
                lhc_rst        => lhc_clk,
                ctrs_in        => ctrs,
                bc0            => bc0,
                ec0            => ec0,
                oc0            => oc0, 
                bx_nr          => open,
                event_nr       => open,
                orbit_nr       => open,
                begin_lumi_sec => begin_lumi_per
            );


    gen_algos_slice_l : for i in 0 to NR_ALGOS - 1 generate
        algos_slice_i : entity work.algo_slice
            generic map(
                RATE_COUNTER_WIDTH    => RATE_COUNTER_WIDTH,
                PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
                PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
            )
            port map(
                sys_clk                          => clk,
                lhc_clk                          => lhc_clk,
                lhc_rst                          => lhc_rst,
                sres_algo_rate_counter           => '0',
                sres_algo_pre_scaler             => '0',
                sres_algo_post_dead_time_counter => '0',
                suppress_cal_trigger             => '0',
                l1a                              => ctrs.l1a, --TODO modify this
                request_update_factor_pulse      => request_factor_update,
                begin_lumi_per                   => begin_lumi_per,
                algo_i                           => algos_in(i),
                algo_del_i                       => algos_delayed(i),
                prescale_factor                  => prscl_fct(i)(PRESCALE_FACTOR_WIDTH-1 downto 0),
                prescale_factor_preview          => prscl_fct_prvw(i)(PRESCALE_FACTOR_WIDTH-1 downto 0),
                algo_bx_mask                     => '1',
                veto_mask                        => '1',
                rate_cnt_before_prescaler        => rate_cnt_before_prescaler(i),
                rate_cnt_after_prescaler         => rate_cnt_after_prescaler(i),
                rate_cnt_after_prescaler_preview => rate_cnt_after_prescaler_preview(i),
                rate_cnt_post_dead_time          => rate_cnt_post_dead_time(i),
                algo_after_bxomask               => algos_after_bxmask(i),
                algo_after_prescaler             => algos_after_prescaler(i),
                algo_after_prescaler_preview     => algos_after_prescaler_preview(i),
                veto                             => open
            );
    end generate;

    algos_after_prescaler_o <= algos_after_prescaler;

    Mask_i : entity work.Mask
        generic map(
            NR_ALGOS => 64*9
        )
        port map(
            clk         => lhc_clk,
            algos_in    => algos_after_prescaler,
            masks       => masks,
            trigger_out => trigger_out
        );

    trgg_o <= trigger_out;




end rtl;
