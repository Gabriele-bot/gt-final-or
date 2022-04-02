library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity algos_slice_RAM_tb is
end entity algos_slice_RAM_tb;

architecture RTL of algos_slice_RAM_tb is
    constant RATE_COUNTER_WIDTH : integer := 32;

    constant SYS_CLK_PERIOD  : time := 8  ns;
    constant CLK_X9_PERIOD   : time := 2.778 ns;
    constant LHC_CLK_PERIOD  : time := CLK_X9_PERIOD*9;

    constant DELTA_T         : time := 0.1 ns;

    -- inputs
    signal lhc_clk, sys_clk, clk_x9 : std_logic;
    signal rst_x9           : std_logic;
    signal sres_counter     : std_logic := '0';
    signal begin_lumi_per   : std_logic := '0';
    signal algos            : std_logic_vector(63 downto 0) := (others => '0');
    signal l1a              : std_logic := '0';

    signal algo_after_prescaler         : std_logic_vector(63 downto 0);
    signal algo_after_prescaler_preview : std_logic_vector(63 downto 0);

    --checking signals
    type algos_array is array (8 downto 0) of std_logic_vector(63 downto 0);
    signal algos_in            : algos_array := (others => (others => '0'));
    signal algos_out_prescaled : algos_array := (others => (others => '0'));
    signal algos_out_prscprvw  : algos_array := (others => (others => '0'));


    signal algos_in_40             : algos_array := (others => (others => '0'));
    signal algos_out_prsc_40       : algos_array := (others => (others => '0'));
    signal algos_out_prscprvw_40   : algos_array := (others => (others => '0'));


    type algos_data is array (8 downto 0) of integer;
    signal algos_data_0 : algos_data := (0,4,1,0,1,0,3,4,3);
    signal algos_data_1 : algos_data := (1,0,4,0,0,0,2,0,1);
    signal algos_data_2 : algos_data := (2,0,1,0,0,0,1,0,0);
    signal algos_data_3 : algos_data := (2,4,0,0,0,0,1,0,1);



    --*********************************Main Body of Code**********************************
begin

    -- Clock
    process
    begin
        sys_clk  <=  '1';
        wait for SYS_CLK_PERIOD/2;
        sys_clk  <=  '0';
        wait for SYS_CLK_PERIOD/2;
    end process;

    -- Clock
    process
    begin
        lhc_clk  <=  '1';
        wait for LHC_CLK_PERIOD/2;
        lhc_clk  <=  '0';
        wait for LHC_CLK_PERIOD/2;
    end process;

    -- Clock
    process
    begin
        clk_x9  <=  '1';
        wait for CLK_X9_PERIOD/2;
        clk_x9  <=  '0';
        wait for CLK_X9_PERIOD/2;
    end process;

    -- Reset
    process
    begin
        rst_x9  <=  '1';
        wait for CLK_X9_PERIOD;
        rst_x9  <=  '1';
        wait for 8*CLK_X9_PERIOD;
        rst_x9  <=  '0';
        wait;
    end process;

    --l1a
    process
    begin
        wait for 250*LHC_CLK_PERIOD;
        l1a <= '1';
        wait for 10*LHC_CLK_PERIOD;
        l1a <= '0';
        wait for 10*LHC_CLK_PERIOD;
        l1a <= '1';
        wait for 100*LHC_CLK_PERIOD;
        l1a <= '0';
    end process;

    --ALGOS
    process (clk_x9)
        variable cnt       : integer := 0;
        variable frame_cnt : integer := 0;
    begin
        if rising_edge(clk_x9) then
            if rst_x9 = '1' then
                algos <= (others => '0');
                frame_cnt := 0;
                cnt := 0;
            else
                case frame_cnt is
                    when 0 => algos  <=  std_logic_vector(to_unsigned(algos_data_0(cnt), 64));
                    when 1 => algos  <=  std_logic_vector(to_unsigned(algos_data_1(cnt), 64));
                    when 2 => algos  <=  std_logic_vector(to_unsigned(algos_data_2(cnt), 64));
                    when 3 => algos  <=  std_logic_vector(to_unsigned(algos_data_3(cnt), 64));
                    when others => algos <= (others => '0');
                end case;
                if cnt >= 8 then
                    cnt := 0;
                    if frame_cnt >= 3 then
                        frame_cnt := 0;
                    else
                        frame_cnt := frame_cnt + 1;
                    end if;
                else
                    cnt := cnt + 1;
                end if;
            end if;

        end if;
    end process;




    -- begin lumi section
    process
    begin
        wait for 250*LHC_CLK_PERIOD;
        begin_lumi_per <=  '1';
        wait for 1*LHC_CLK_PERIOD;
        begin_lumi_per  <=  '0';
        wait for 550*LHC_CLK_PERIOD;
        begin_lumi_per <=  '1';
        wait for 1*LHC_CLK_PERIOD;
        begin_lumi_per  <=  '0';
    end process;

    ------------------- Checking ------------------------------

    process (clk_x9)
    begin
        if falling_edge(clk_x9) then
            algos_in            <=  algos_in(7 downto 0)            & algos;
            algos_out_prescaled <=  algos_out_prescaled(7 downto 0) & algo_after_prescaler;
            algos_out_prscprvw  <=  algos_out_prscprvw(7 downto 0)  & algo_after_prescaler_preview;
        end if;
    end process;

    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            algos_in_40           <=  algos_in;
            algos_out_prsc_40     <=  algos_out_prescaled;
            algos_out_prscprvw_40 <=  algos_out_prscprvw;
        end if;
    end process;





    ------------------- Instantiate  modules  -----------------

    dut :  entity work.algos_slice_RAM
        generic map(
            RATE_COUNTER_WIDTH    => RATE_COUNTER_WIDTH,
            PRESCALE_FACTOR_WIDTH => 24,
            PRESCALE_FACTOR_INIT  => X"00000064",
            MAX_DELAY             => 127
        )
        port map(
            sys_clk                          => sys_clk,
            lhc_clk                          => lhc_clk,
            lhc_rst                          => '0',
            clk_x9                           => clk_x9,
            rst_x9                           => rst_x9,
            sres_algo_rate_counter           => '0',
            sres_algo_pre_scaler             => '0',
            sres_algo_post_dead_time_counter => '0',
            --suppress_cal_trigger             => '0',
            l1a                              => l1a,
            l1a_latency_delay                => "0010010", --18
            --request_update_factor_pulse      => '0',
            begin_lumi_per                   => begin_lumi_per,
            algos_i                          => algos,
            prescale_factor                  => X"0001D3", --4.67
            prescale_factor_preview          => X"000123", --2.91
            algo_bx_mask                     => '1',
            veto_mask                        => '1',
            rate_cnt_before_prescaler        => open,
            rate_cnt_after_prescaler         => open,
            rate_cnt_after_prescaler_preview => open,
            rate_cnt_post_dead_time          => open,
            algo_after_bxomask               => open,
            algo_after_prescaler             => algo_after_prescaler,
            algo_after_prescaler_preview     => algo_after_prescaler_preview,
            veto                             => open
        );



end architecture RTL;
