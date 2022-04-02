library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_monitoring_module.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.P2GT_monitor_pkg.all;

entity monitoring_module is
    port(
        clk                 : in std_logic;
        rst                 : in std_logic;
        ipb_in              : in ipb_wbus;
        ipb_out             : out ipb_rbus;
        -- ==========================================================================
        clk_payload : in  std_logic_vector(2 downto 0);
        rst_payload : in  std_logic_vector(2 downto 0);
        clk_p       : in  std_logic;        -- data clock
        rst_loc     : in  std_logic_vector(N_REGION - 1 downto 0);
        clken_loc   : in  std_logic_vector(N_REGION - 1 downto 0);
        bcres               : in std_logic;
        test_en             : in std_logic;
        l1a                 : in  std_logic_vector(N_REGION - 1 downto 0);
        begin_lumi_section  : in std_logic;
        d           : in  ldata(3 downto 0);  -- data in
        q           : out ldata(3 downto 0)   -- data out
    );
end entity monitoring_module;

architecture RTL of monitoring_module is


    signal algos_in : std_logic_vector(63 downto 0) := (others => '0');

    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

    signal ctrl_reg : ipb_reg_v(0 downto 0);


    signal begin_lumi_per_ipbus        : std_logic;
    signal begin_lumi_per              : std_logic;
    signal l1a_latency_delay           : std_logic_vector(6 downto 0);

    -- rate counter ipb regs
    signal rate_cnt_before_prescaler        : ipb_reg_v(9*64-1 downto 0);
    signal rate_cnt_after_prescaler         : ipb_reg_v(9*64-1 downto 0);
    signal rate_cnt_after_prescaler_preview : ipb_reg_v(9*64-1 downto 0);
    signal rate_cnt_post_dead_time          : ipb_reg_v(9*64-1 downto 0);
    
begin

    fabric_i: entity work.ipbus_fabric_sel
        generic map(
            NSLV => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_monitoring_module(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );
        
        rate_cnt_before_prsc_regs : entity work.ipbus_syncreg_v
        generic map(
            N_CTRL     => 0,
            N_STAT     => 9*64
        )
        port map(
            clk       => clk,
            rst       => rst,
            ipb_in    => ipb_to_slaves(N_SLV_CNT_RATE_BEFORE_PRSC),
            ipb_out   => ipb_from_slaves(N_SLV_CNT_RATE_BEFORE_PRSC),
            slv_clk   => clk_p,
            d         => rate_cnt_before_prescaler,
            q         => open,
            qmask     => open,
            stb       => open,
            rstb      => open
        );

    rate_cnt_after_prsc_regs : entity work.ipbus_syncreg_v
        generic map(
            N_CTRL     => 0,
            N_STAT     => 9*64
        )
        port map(
            clk       => clk,
            rst       => rst,
            ipb_in    => ipb_to_slaves(N_SLV_CNT_RATE_AFTER_PRSC),
            ipb_out   => ipb_from_slaves(N_SLV_CNT_RATE_AFTER_PRSC),
            slv_clk   => clk_p,
            d         => rate_cnt_after_prescaler,
            q         => open,
            qmask     => open,
            stb       => open,
            rstb      => open
        );

    rate_cnt_after_prsc_prvw_regs : entity work.ipbus_syncreg_v
        generic map(
            N_CTRL     => 0,
            N_STAT     => 9*64
        )
        port map(
            clk       => clk,
            rst       => rst,
            ipb_in    => ipb_to_slaves(N_SLV_CNT_RATE_AFTER_PRSC_PRVW),
            ipb_out   => ipb_from_slaves(N_SLV_CNT_RATE_AFTER_PRSC_PRVW),
            slv_clk   => clk_p,
            d         => rate_cnt_after_prescaler_preview,
            q         => open,
            qmask     => open,
            stb       => open,
            rstb      => open
        );
        
        rate_cnt_pdt_regs : entity work.ipbus_syncreg_v
        generic map(
            N_CTRL     => 0,
            N_STAT     => 9*64
        )
        port map(
            clk       => clk,
            rst       => rst,
            ipb_in    => ipb_to_slaves(N_SLV_CNT_RATE_PDT),
            ipb_out   => ipb_from_slaves(N_SLV_CNT_RATE_PDT),
            slv_clk   => clk_p,
            d         => rate_cnt_post_dead_time,
            q         => open,
            qmask     => open,
            stb       => open,
            rstb      => open
        );
        
        ctrl_regs : entity work.ipbus_syncreg_v
        generic map(
            N_CTRL     => 1,
            N_STAT     => 0
        )
        port map(
            clk       => clk,
            rst       => rst,
            ipb_in    => ipb_to_slaves(N_SLV_CTRL),
            ipb_out   => ipb_from_slaves(N_SLV_CTRL),
            slv_clk   => clk_p,
            d         => open,
            q         => ctrl_reg,
            qmask     => open,
            stb       => open,
            rstb      => open
        );

    begin_lumi_per_ipbus <= ctrl_reg(0)(1);
    l1a_latency_delay    <= ctrl_reg(0)(7 downto 1);
    
    -- xpm_cdc_pulse: Pulse Transfer
    -- Xilinx Parameterized Macro, version 2020.1
    xpm_cdc_pulse_inst : xpm_cdc_pulse
        generic map (
            DEST_SYNC_FF => 4, -- DECIMAL; range: 2-10
            INIT_SYNC_FF => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            REG_OUTPUT => 0, -- DECIMAL; 0=disable registered output, 1=enable registered output
            RST_USED => 1, -- DECIMAL; 0=no reset, 1=implement reset
            SIM_ASSERT_CHK => 0 -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        )
        port map (
            dest_pulse => begin_lumi_per, -- 1-bit output: Outputs a pulse the size of one dest_clk period when a pulse
            -- transfer is correctly initiated on src_pulse input. This output is
            -- combinatorial unless REG_OUTPUT is set to 1.
            dest_clk => clk_payload(0), -- 1-bit input: Destination clock.
            dest_rst => rst_payload(0), -- 1-bit input: optional; required when RST_USED = 1
            src_clk => clk, -- 1-bit input: Source clock.
            src_pulse => begin_lumi_per_ipbus, -- 1-bit input: Rising edge of this signal initiates a pulse transfer to the
            -- destination clock domain. The minimum gap between each pulse transfer must
            -- be at the minimum 2*(larger(src_clk period, dest_clk period)). This is
            -- measured between the falling edge of a src_pulse to the rising edge of the
            -- next src_pulse. This minimum gap will guarantee that each rising edge of
            -- src_pulse will generate a pulse the size of one dest_clk period in the
            -- destination clock domain. When RST_USED = 1, pulse transfers will not be
            -- guaranteed while src_rst and/or dest_rst are asserted.
            src_rst => rst -- 1-bit input: optional; required when RST_USED = 1
        );
    -- End of xpm_cdc_pulse_inst instantiation

    
    process(d(0)) is
    begin
        if d(0).valid = '1' then
            algos_in <= d(0).data;
        else
            algos_in <= (others => '0');
         end if;
    end process;
    
    algos_slice : entity work.algos_slice_RAM
        generic map(
            RATE_COUNTER_WIDTH    => RATE_COUNTER_WIDTH,
            PRESCALE_FACTOR_WIDTH => 24,
            PRESCALE_FACTOR_INIT  => X"00000064", --1.00
            MAX_DELAY             => 127
        )
        port map(
            sys_clk                          => clk,
            lhc_clk                          => clk_payload(0),
            lhc_rst                          => rst_payload(0),
            clk_x9                           => clk_p,
            rst_x9                           => rst_loc(0),
            sres_algo_rate_counter           => '0',
            sres_algo_pre_scaler             => '0',
            sres_algo_post_dead_time_counter => '0',
            l1a                              => l1a(0),
            l1a_latency_delay                => l1a_latency_delay,
            begin_lumi_per                   => begin_lumi_per,
            algos_i                          => algos_in,
            prescale_factor                  => X"0001D3", --4.67
            prescale_factor_preview          => X"000123", --2.91
            algo_bx_mask                     => '1',
            veto_mask                        => '1',
            rate_cnt_before_prescaler        => rate_cnt_before_prescaler,
            rate_cnt_after_prescaler         => rate_cnt_after_prescaler,
            rate_cnt_after_prescaler_preview => rate_cnt_after_prescaler_preview,
            rate_cnt_post_dead_time          => rate_cnt_post_dead_time,
            algo_after_bxomask               => open,
            algo_after_prescaler             => q(0).data,
            algo_after_prescaler_preview     => q(2).data,
            veto                             => open
        );
        
    q(0).valid  <= d(0).valid;
    q(0).start  <= d(0).start;
    q(0).strobe <= d(0).strobe;
    
    q(1) <= d(1);
        
    q(2).valid  <= d(0).valid;
    q(2).start  <= d(0).start;
    q(2).strobe <= d(0).strobe;
    
    q(3) <= d(3);

end architecture RTL;
