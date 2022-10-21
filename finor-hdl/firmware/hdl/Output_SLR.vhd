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
        MAX_DELAY            : natural := 127
        );
    port(
        clk         : in  std_logic;        -- ipbus signals
        rst         : in  std_logic;
        ipb_in      : in  ipb_wbus;
        ipb_out     : out ipb_rbus;
        --==========================================================--
        clk_p       : in std_logic;
        rst_p       : in std_logic;
        lhc_clk     : in std_logic;
        lhc_rst     : in std_logic;
        
        ctrs                     : in  ttc_stuff_t;
        
        q           : out ldata(0 downto 0);             -- data out
        trgg_0      : in std_logic_vector(N_TRIGG-1 downto 0);
        trgg_1      : in std_logic_vector(N_TRIGG-1 downto 0)

    );
end entity Output_SLR;

architecture RTL of Output_SLR is
    
    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

    signal Final_OR, Final_OR_delayed : std_logic_vector(N_TRIGG-1 downto 0);
    
    -- counters and bgos signals
    signal bc0, oc0, ec0               : std_logic := '0';
    signal begin_lumi_per              : std_logic;
    signal begin_lumi_per_del1         : std_logic;
    signal l1a_latency_delay           : std_logic_vector(log2c(MAX_DELAY)-1 downto 0);

    constant finor_latency : integer := 3;
    signal ctrs_internal               : ttc_stuff_array(finor_latency downto 0);
    
    signal rate_cnt_finor        : ipb_reg_v(N_TRIGG - 1 downto 0);
    signal rate_cnt_finor_pdt    : ipb_reg_v(N_TRIGG - 1 downto 0);
    
    signal ctrl_reg : ipb_reg_v(0 downto 0);
    signal stat_reg : ipb_reg_v(0 downto 0);
    
    type state_t is (idle, start, increment);
    signal state           : state_t := idle;
    
    signal addr   : unsigned(log2c(N_TRIGG)-1 downto 0);
    signal we     : std_logic;
    signal ready  : std_logic;
    signal d_rate_cnt_finor, d_rate_cnt_finor_pdt       : std_logic_vector(31 downto 0);

begin
    
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
    --TODO Where to stat counting, need some latency? How much?
    ctrs_internal(0) <= ctrs;
    bx_cnt_int_p : process(lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            ctrs_internal(finor_latency downto 1) <= ctrs_internal(finor_latency - 1 downto 0);
        end if;
    end process;
    
    Counters_i : entity work.Counter_module
        generic map (
            BEGIN_LUMI_BIT => 18
        )
        port map (
            lhc_clk        => lhc_clk,
            lhc_rst        => lhc_rst,
            ctrs_in        => ctrs_internal(finor_latency),
            bc0            => bc0,
            ec0            => ec0,
            oc0            => oc0,
            bx_nr          => open,
            event_nr       => open,
            orbit_nr       => open,
            begin_lumi_sec => begin_lumi_per,
            test_en        => open
            
        );
        
    Ctrl_stat_regs : entity work.ipbus_ctrlreg_v
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
            src_in   => ctrl_reg(0)(log2c(MAX_DELAY) - 1 downto 0)
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
    
        
    -- rate counters are updated with begin_lumi_per_del1
    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            begin_lumi_per_del1 <= begin_lumi_per;
        end if;
    end process;
    
    delay_element_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => N_TRIGG,
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk    => lhc_clk,
            rst    => lhc_rst,
            data_i => Final_OR,
            data_o => Final_OR_delayed,
            delay  => l1a_latency_delay
        );


    Final_OR_p : process (trgg_0, trgg_1)
    begin
        Final_OR <= trgg_0 or trgg_1;
    end process;

    gen_rate_counters_l : for i in 0 to N_TRIGG - 1 generate
        rate_counters_i : entity work.algo_rate_counter
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                sys_clk         => clk,
                clk             => lhc_clk,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per_del1,
                algo_i          => Final_OR(i),
                counter_o       => rate_cnt_finor(i)
            ) ;
            
            rate_countrs_pdt_i : entity work.algo_rate_counter_pdt
                generic map(
                    COUNTER_WIDTH => RATE_COUNTER_WIDTH
                ) 
                port map(
                    sys_clk         => clk,
                    lhc_clk         => lhc_clk,
                    lhc_rst         => lhc_rst,
                    sres_counter    => '0',
                    store_cnt_value => begin_lumi_per_del1,
                    l1a             => ctrs_internal(finor_latency).l1a,
                    algo_del_i      => Final_OR_delayed(i),
                    counter_o       => rate_cnt_finor_pdt(i)
                ) ;
    end generate;
    
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
                    d_rate_cnt_finor      <= rate_cnt_finor(0);
                    d_rate_cnt_finor_pdt  <= rate_cnt_finor_pdt(0);
                    state <= increment;
                when increment =>
                    addr <= addr + 1;
                    we   <= '1';
                    d_rate_cnt_finor      <= rate_cnt_finor(to_integer(addr + 1));
                    d_rate_cnt_finor_pdt  <= rate_cnt_finor_pdt(to_integer(addr + 1));
                    if addr >= N_TRIGG-2 then --(2 is due to latency)
                        state <= idle;
                    end if;
            end case;
        end if;
    end process;
    
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
            rclk    => lhc_clk,
            we      => we,
            d       => d_rate_cnt_finor,
            q       => open,
            addr    => std_logic_vector(addr)
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
            rclk    => lhc_clk,
            we      => we,
            d       => d_rate_cnt_finor_pdt,
            q       => open,
            addr    => std_logic_vector(addr)
        );




    process(clk_p)
    begin
        if rising_edge(clk_p) then
            if (rst_p = '1') then
                q(0).data  <= (others => '0');
                q(0).valid  <= '0';
                q(0).start  <= '0';
                q(0).strobe <= '1';
            else
                q(0).data(N_TRIGG -1 downto 0)  <= Final_OR;
                q(0).data(63 downto N_TRIGG) <= (others => '0');
                q(0).valid  <= '1';
                q(0).start  <= '1';
                q(0).strobe <= '1';
            end if;
        end if;


    end process;



end architecture RTL;