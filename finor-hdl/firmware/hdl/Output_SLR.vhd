library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.ipbus_decode_Output_SLR.all;

use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.math_pkg.all;
use work.P2GT_finor_pkg.all;

entity Output_SLR is
    generic(
        BEGIN_LUMI_TOGGLE_BIT : natural := 18;
        MAX_DELAY             : natural := MAX_DELAY_PDT
    );
    port(
        clk         : in  std_logic;        -- ipbus signals
        rst         : in  std_logic;
        ipb_in      : in  ipb_wbus;
        ipb_out     : out ipb_rbus;
        --==========================================================--
        clk360      : in std_logic;
        rst360      : in std_logic;
        clk40       : in std_logic;
        rst40       : in std_logic;

        ctrs        : in  ttc_stuff_t;
        
        delay_lkd   : in std_logic;
        delay_in    : in std_logic_vector(log2c(MAX_CTRS_DELAY_360) - 1 downto 0);

        valid_in    : in std_logic;

        trgg_0      : in std_logic_vector(N_TRIGG-1 downto 0);
        trgg_1      : in std_logic_vector(N_TRIGG-1 downto 0);
        trgg_prvw_0 : in std_logic_vector(N_TRIGG-1 downto 0);
        trgg_prvw_1 : in std_logic_vector(N_TRIGG-1 downto 0);
        veto_0      : in std_logic;
        veto_1      : in std_logic;

        q           : out ldata(0 downto 0)             -- data out
    );
end entity Output_SLR;

architecture RTL of Output_SLR is
    
    constant N_CTRL_REGS        : integer := 1;
    constant N_STAT_REGS        : integer := 1; 

    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

    signal frame_cntr : integer range 0 to 8;

    signal valid_in_del : std_logic;
    signal valid_out, start_out, start_of_orbit_out, last_out : std_logic;
    signal link_out : lword;


    signal Final_OR, Final_OR_delayed : std_logic_vector(N_TRIGG-1 downto 0);
    signal Final_OR_preview, Final_OR_preview_delayed     : std_logic_vector(N_TRIGG-1 downto 0);
    signal Final_OR_with_veto, Final_OR_with_veto_delayed : std_logic_vector(N_TRIGG-1 downto 0);
    signal Final_OR_preview_with_veto, Final_OR_preview_with_veto_delayed : std_logic_vector(N_TRIGG-1 downto 0);

    -- counters and bgos signals
    signal bc0, oc0, ec0               : std_logic := '0';
    signal begin_lumi_per              : std_logic;
    signal begin_lumi_per_del1         : std_logic;
    signal end_lumi_per                : std_logic;
    signal l1a_latency_delay           : std_logic_vector(log2c(MAX_DELAY)-1 downto 0);

    signal ctrs_internal               : ttc_stuff_t;
    signal ctrs_align                  : ttc_stuff_t;

    signal rate_cnt_finor        : ipb_reg_v(N_TRIGG - 1 downto 0);
    signal rate_cnt_finor_pdt    : ipb_reg_v(N_TRIGG - 1 downto 0);
    signal rate_cnt_finor_prvw        : ipb_reg_v(N_TRIGG - 1 downto 0);
    signal rate_cnt_finor_prvw_pdt    : ipb_reg_v(N_TRIGG - 1 downto 0);
    signal rate_cnt_finor_with_veto        : ipb_reg_v(N_TRIGG - 1 downto 0);
    signal rate_cnt_finor_with_veto_pdt    : ipb_reg_v(N_TRIGG - 1 downto 0);
    signal rate_cnt_finor_prvw_with_veto        : ipb_reg_v(N_TRIGG - 1 downto 0);
    signal rate_cnt_finor_prvw_with_veto_pdt    : ipb_reg_v(N_TRIGG - 1 downto 0);

    signal ctrl_reg : ipb_reg_v(N_CTRL_REGS - 1 downto 0) := (others => (others => '0'));
    signal stat_reg : ipb_reg_v(N_STAT_REGS - 1 downto 0) := (others => (others => '0'));

    type state_t is (idle, start, increment);
    signal state           : state_t := idle;

    signal addr   : std_logic_vector(log2c(N_TRIGG)-1 downto 0);
    signal we     : std_logic;
    signal ready  : std_logic;
    signal d_rate_cnt_finor, d_rate_cnt_finor_pdt                               : std_logic_vector(31 downto 0);
    signal d_rate_cnt_finor_prvw, d_rate_cnt_finor_prvw_pdt                     : std_logic_vector(31 downto 0);
    signal d_rate_cnt_finor_with_veto, d_rate_cnt_finor_with_veto_pdt           : std_logic_vector(31 downto 0);
    signal d_rate_cnt_finor_prvw_with_veto, d_rate_cnt_finor_prvw_with_veto_pdt : std_logic_vector(31 downto 0);

    signal veto_out_s               : std_logic;
    signal veto_cnt                 : std_logic_vector(RATE_COUNTER_WIDTH-1 DOWNTO 0);
    signal veto_stat_reg            : ipb_reg_v(0 downto 0);

begin


    frame_counter_p : process (clk360)
    begin
        if rising_edge(clk360) then -- rising clock edge
            valid_in_del <= valid_in;
            if valid_in = '0' then
                frame_cntr <= 0;
            elsif frame_cntr < 8 then
                frame_cntr <= frame_cntr + 1;
            else
                frame_cntr <= 0;
            end if;
        end if;
    end process frame_counter_p;


    fabric_i: entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_output_slr(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    ----------------------------------------------------------------------------------
    ---------------COUNTERS INTERNAL---------------------------------------------------
    ----------------------------------------------------------------------------------
    
    ctrs_align_i : entity work.CTRS_fixed_alignment
        generic map(
            MAX_LATENCY_360 => MAX_CTRS_DELAY_360,
            DELAY_OFFSET    => 9+9+4 --deserializer + SLR cross
        )
        port map(
            clk360         => clk360,
            rst360         => rst360,
            clk40          => clk40,
            rst40          => rst40,
            ctrs_delay_lkd => delay_lkd,
            ctrs_delay_val => delay_in,
            ctrs_in        => ctrs,
            ctrs_out       => ctrs_align
        );
        
    bx_cnt_int_p : process(clk40)
    begin
        if rising_edge(clk40) then
            ctrs_internal <= ctrs_align;
        end if;
    end process;

    Counters_i : entity work.Counter_module
        generic map (
            BEGIN_LUMI_BIT => BEGIN_LUMI_TOGGLE_BIT
        )
        port map (
            clk40          => clk40,
            rst40          => rst40,
            ctrs_in        => ctrs_internal,
            bc0            => bc0,
            ec0            => ec0,
            oc0            => oc0,
            bx_nr          => open,
            event_nr       => open,
            orbit_nr       => open,
            begin_lumi_sec => begin_lumi_per,
            end_lumi_sec   => end_lumi_per,
            test_en        => open

        );


    rate_cntrs_read_FSM_i : entity work.write_FSM
        generic map(
            RAM_DEPTH => N_TRIGG
        )
        port map(
            clk        => clk40,
            rst        => rst40,
            write_flag => begin_lumi_per_del1,
            addr_o     => addr,
            addr_w_o   => open,
            we_o       => we
        ) ;

    Ctrl_stat_regs : entity work.ipbus_ctrlreg_cdc_v
        generic map(
            N_CTRL         => N_CTRL_REGS,
            N_STAT         => N_STAT_REGS,
            DEST_SYNC_FF   => 3,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map(
            clk       => clk,
            rst       => rst,
            ipb_in    => ipb_to_slaves(N_SLV_CSR),
            ipb_out   => ipb_from_slaves(N_SLV_CSR),
            slv_clk   => clk40,
            d         => stat_reg,
            q         => ctrl_reg,
            qmask     => open,
            stb       => open
        );
        
    l1a_latency_delay <= ctrl_reg(0)(log2c(MAX_DELAY) - 1 downto 0);
    
    ready <= not we;
    
    stat_reg(0)(0) <= ready;


    -- rate counters are updated with begin_lumi_per_del1
    process (clk40)
    begin
        if rising_edge(clk40) then
            begin_lumi_per_del1 <= begin_lumi_per;
        end if;
    end process;
    

    
    Final_OR           <= trgg_0 or trgg_1;
    Final_OR_preview   <= trgg_prvw_0 or trgg_prvw_1;

    Final_OR_with_veto_l : for i in 0 to N_TRIGG -1 generate
        Final_OR_with_veto(i)         <= (trgg_0(i) or trgg_1(i)) and not(veto_0 or veto_1);
        Final_OR_preview_with_veto(i) <= (trgg_prvw_0(i) or trgg_prvw_1(i)) and not(veto_0 or veto_1);
    end generate;

    delay_element_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => N_TRIGG,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => Final_OR,
            data_o    => Final_OR_delayed,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );

    delay_element_preview_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => N_TRIGG,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => Final_OR_preview,
            data_o    => Final_OR_preview_delayed,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );


    delay_element_veto_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => N_TRIGG,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => Final_OR_with_veto,
            data_o    => Final_OR_with_veto_delayed,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );

    delay_element_preview_veto_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => N_TRIGG,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk       => clk40,
            rst       => rst40,
            data_i    => Final_OR_preview_with_veto,
            data_o    => Final_OR_preview_with_veto_delayed,
            delay_lkd => '1',
            delay     => l1a_latency_delay
        );


    veto_out_s <= veto_0 or veto_1;

    ----------------------------------------------------------------------------------
    -----------------------------Veto Rate Counter------------------------------------
    ----------------------------------------------------------------------------------   

    Veto_rate_counter_i: entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => RATE_COUNTER_WIDTH
        )
        port map(
            clk40           => clk40,
            rst40           => rst40,
            sres_counter    => '0',
            store_cnt_value => begin_lumi_per_del1,
            algo_i          => veto_out_s,
            counter_o       => veto_cnt
        );

     Veto_cnt_regs : entity work.ipbus_ctrlreg_cdc_v
        generic map(
            N_CTRL         => 0,
            N_STAT         => 1,
            DEST_SYNC_FF   => 3,
            INIT_SYNC_FF   => 0,
            SIM_ASSERT_CHK => 0,
            SRC_INPUT_REG  => 1
        )
        port map(
            clk       => clk,
            rst       => rst,
            ipb_in    => ipb_to_slaves(N_SLV_VETO_REG),
            ipb_out   => ipb_from_slaves(N_SLV_VETO_REG),
            slv_clk   => clk40,
            d         => veto_stat_reg,
            q         => open,
            qmask     => open,
            stb       => open
        );

    veto_stat_reg(0)(RATE_COUNTER_WIDTH - 1 downto 0) <= veto_cnt;

    gen_rate_counters_l : for i in 0 to N_TRIGG - 1 generate
        rate_counters_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                algo_i          => Final_OR(i),
                counter_o       => rate_cnt_finor(i)
            ) ;

        rate_counters_pdt_i : entity work.algo_rate_counter_pdt
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                l1a             => ctrs_align.l1a,
                algo_del_i      => Final_OR_delayed(i),
                counter_o       => rate_cnt_finor_pdt(i)
            ) ;


        rate_counters_preview_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                algo_i          => Final_OR_preview(i),
                counter_o       => rate_cnt_finor_prvw(i)
            ) ;

        rate_counters_preview_pdt_i : entity work.algo_rate_counter_pdt
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                l1a             => ctrs_align.l1a,
                algo_del_i      => Final_OR_preview_delayed(i),
                counter_o       => rate_cnt_finor_prvw_pdt(i)
            ) ;


        rate_counters_veto_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                algo_i          => Final_OR_with_veto(i),
                counter_o       => rate_cnt_finor_with_veto(i)
            ) ;

        rate_counters_veto_pdt_i : entity work.algo_rate_counter_pdt
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                l1a             => ctrs_align.l1a,
                algo_del_i      => Final_OR_with_veto_delayed(i),
                counter_o       => rate_cnt_finor_with_veto_pdt(i)
            ) ;

        rate_counters_preview_veto_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                algo_i          => Final_OR_preview_with_veto(i),
                counter_o       => rate_cnt_finor_prvw_with_veto(i)
            ) ;

        rate_counters_preview_veto_pdt_i : entity work.algo_rate_counter_pdt
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                clk40           => clk40,
                rst40           => rst40,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per,
                l1a             => ctrs_align.l1a,
                algo_del_i      => Final_OR_preview_with_veto_delayed(i),
                counter_o       => rate_cnt_finor_prvw_with_veto_pdt(i)
            ) ;
    end generate;

    d_rate_cnt_finor                     <= rate_cnt_finor                   (to_integer(unsigned(addr)));
    d_rate_cnt_finor_pdt                 <= rate_cnt_finor_pdt               (to_integer(unsigned(addr)));
    d_rate_cnt_finor_prvw                <= rate_cnt_finor_prvw              (to_integer(unsigned(addr)));
    d_rate_cnt_finor_prvw_pdt            <= rate_cnt_finor_prvw_pdt          (to_integer(unsigned(addr)));
    d_rate_cnt_finor_with_veto           <= rate_cnt_finor_with_veto         (to_integer(unsigned(addr)));
    d_rate_cnt_finor_with_veto_pdt       <= rate_cnt_finor_with_veto_pdt     (to_integer(unsigned(addr)));
    d_rate_cnt_finor_prvw_with_veto      <= rate_cnt_finor_prvw_with_veto    (to_integer(unsigned(addr)));
    d_rate_cnt_finor_prvw_with_veto_pdt  <= rate_cnt_finor_prvw_with_veto_pdt(to_integer(unsigned(addr)));

    --==================================================================================================--
    --======================================Rate couter RAMs============================================--
    --==================================================================================================--
    rate_cnt_finor_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_FINOR),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor,
            q       => open,
            addr    => addr
        );


    rate_cnt_finor_pdt_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_FINOR_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_pdt,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_preview_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_FINOR_PREVIEW),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_prvw,
            q       => open,
            addr    => addr
        );


    rate_cnt_finor_preview_pdt_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_FINOR_PREVIEW_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_prvw_pdt,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_with_veto_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_FINOR_WITH_VETO),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_WITH_VETO),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_with_veto,
            q       => open,
            addr    => addr
        );


    rate_cnt_finor_with_veto_pdt_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_FINOR_WITH_VETO_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_WITH_VETO_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_with_veto_pdt,
            q       => open,
            addr    => addr
        );

    rate_cnt_finor_preview_with_veto_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_FINOR_PREVIEW_WITH_VETO),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_WITH_VETO),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_prvw_with_veto,
            q       => open,
            addr    => addr
        );


    rate_cnt_finor_preview_with_veto_pdt_regs : entity work.ipbus_initialized_dpram
        generic map(
            INIT_VALUE => X"00000000",
            ADDR_WIDTH => log2c(N_TRIGG),
            DATA_WIDTH => 32
        )
        port map(
            clk     => clk,
            rst     => rst,
            ipb_in  => ipb_to_slaves  (N_SLV_CNT_RATE_FINOR_PREVIEW_WITH_VETO_PDT),
            ipb_out => ipb_from_slaves(N_SLV_CNT_RATE_FINOR_PREVIEW_WITH_VETO_PDT),
            rclk    => clk40,
            we      => we,
            d       => d_rate_cnt_finor_prvw_with_veto_pdt,
            q       => open,
            addr    => addr
        );

    link_out.data(N_TRIGG   - 1 downto 0)         <= Final_OR when frame_cntr = 0 and valid_in = '1' else (others => '0');
    link_out.data(N_TRIGG*2 - 1 downto N_TRIGG)   <= Final_OR_preview when frame_cntr = 0 and valid_in = '1' else (others => '0');
    link_out.data(N_TRIGG*3 - 1 downto 2*N_TRIGG) <= Final_OR_with_veto when frame_cntr = 0 and valid_in = '1' else (others => '0');
    link_out.data(N_TRIGG*4 - 1 downto 3*N_TRIGG) <= Final_OR_preview_with_veto when frame_cntr = 0 and valid_in = '1' else (others => '0');

    link_out.valid          <= valid_in;
    link_out.start          <= '1' when frame_cntr = 0 and valid_in = '1' else '0';
    link_out.last           <= '1' when frame_cntr = 8 and valid_in = '1' else '0';
    link_out.start_of_orbit <= '1' when frame_cntr = 0 and valid_in = '1' and (ctrs_internal.bctr = std_logic_vector(to_unsigned(0,12))) else '0';


    output_p: process(clk360)
    begin
        if rising_edge(clk360) then
            if (rst360 = '1') then
                q(0).data           <= (others => '0');
                q(0).valid          <= '0';
                q(0).start_of_orbit <= '0';
                q(0).start          <= '0';
                q(0).last           <= '0';
                --q(0).strobe         <= '1';
            else
                q(0) <= link_out;
                --q(0).strobe         <= '1';
            end if;
        end if;


    end process;



end architecture RTL;