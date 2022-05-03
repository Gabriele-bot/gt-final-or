library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pkg.all;
use work.P2GT_monitor_pkg.all;

library xpm;
use xpm.vcomponents.all;


entity algos_slice_RAM is
    generic(
        RATE_COUNTER_WIDTH    : integer := 32;
        PRESCALE_FACTOR_WIDTH : integer := 24;
        PRESCALE_FACTOR_INIT  : unsigned(31 DOWNTO 0) := X"00000064"; --1.00
        MAX_DELAY             : integer := 63
    );
    port(
        --clocks
        sys_clk : in std_logic;
        lhc_clk : in std_logic;
        lhc_rst : in std_logic;
        clk_x9  : in std_logic;
        rst_x9  : in std_logic;

        -- HB 2015-09-17: added "sres_algo_rate_counter" and "sres_algo_pre_scaler"
        -- counters synchronous resets 
        sres_algo_rate_counter           : in std_logic;
        sres_algo_pre_scaler             : in std_logic;
        sres_algo_post_dead_time_counter : in std_logic;

        -- HB 2016-06-17: added suppress_cal_trigger, used to suppress counting algos caused by calibration trigger at bx=3490.
        --suppress_cal_trigger : in std_logic; -- pos. active signal: '1' = suppression of algos caused by calibration trigger !!!

        -- HB 2015-09-2: added "l1a" and "l1a_latency_delay" for post-dead-time counter
        l1a               : in std_logic;
        l1a_latency_delay : in std_logic_vector(log2c(MAX_DELAY)-1 downto 0); -- in the 40MHz domain, need to change it to the 360MHz domain  

        begin_lumi_per              : in std_logic;
        algos_i                     : in std_logic_vector(63 downto 0);
        prescale_factor             : in std_logic_vector(PRESCALE_FACTOR_WIDTH-1 DOWNTO 0);
        prescale_factor_preview     : in std_logic_vector(PRESCALE_FACTOR_WIDTH-1 DOWNTO 0);

        --prescale_factor             : in prescale_factor_array;
        --prescale_factor_preview     : in prescale_factor_array;

        algo_bx_mask : in std_logic; -- Dont know
        veto_mask    : in std_logic; -- Dont know

        rate_cnt_before_prescaler        : out rate_counter_array;
        rate_cnt_after_prescaler         : out rate_counter_array;
        rate_cnt_after_prescaler_preview : out rate_counter_array;
        rate_cnt_post_dead_time          : out rate_counter_array;

        algo_after_bxomask           : out std_logic_vector(63 downto 0); -- Dont know
        algo_after_prescaler         : out std_logic_vector(63 downto 0);
        algo_after_prescaler_preview : out std_logic_vector(63 downto 0);

        veto : out std_logic -- Dont know
    );
end entity algos_slice_RAM;

architecture RTL of algos_slice_RAM is

    signal r_addr   : std_logic_vector(3 downto 0) := (others => '0');
    signal addr_int : std_logic_vector(3 downto 0) := (others => '0');
    signal w_addr   : std_logic_vector(3 downto 0) := (others => '0'); -- initialized to 8 

    --delay
    signal l1a_latency_delay_x9           : unsigned(log2c(MAX_DELAY*9)-1 downto 0);

    signal algos_delayed                  : std_logic_vector(63 downto 0);
    signal algo_after_prescaler_s         : std_logic_vector(63 downto 0);
    signal algo_after_prescaler_preview_s : std_logic_vector(63 downto 0);
    -- rate counters
    signal counter_rate_bp_o   : std_logic_vector(64*RATE_COUNTER_WIDTH-1 DOWNTO 0) := (others => '0'); -- 32x64 before prescaler
    signal counter_rate_bp_i   : std_logic_vector(64*RATE_COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal counter_rate_ap_o   : std_logic_vector(64*RATE_COUNTER_WIDTH-1 DOWNTO 0) := (others => '0'); -- 32x64 after prescaler
    signal counter_rate_ap_i   : std_logic_vector(64*RATE_COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal counter_rate_app_o  : std_logic_vector(64*RATE_COUNTER_WIDTH-1 DOWNTO 0) := (others => '0'); -- 32x64 after prescaler preview
    signal counter_rate_app_i  : std_logic_vector(64*RATE_COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal counter_rate_pdt_o  : std_logic_vector(64*RATE_COUNTER_WIDTH-1 DOWNTO 0) := (others => '0'); -- 32x64 post dead time
    signal counter_rate_pdt_i  : std_logic_vector(64*RATE_COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');

    -- prescaler counters
    signal counter_prsc_o      : std_logic_vector((PRESCALE_FACTOR_WIDTH)*64 -1 DOWNTO 0) := (others => '0');
    signal counter_prsc_i      : std_logic_vector((PRESCALE_FACTOR_WIDTH)*64 -1 DOWNTO 0) := (others => '0');
    signal counter_prsc_prvw_o : std_logic_vector((PRESCALE_FACTOR_WIDTH)*64 -1 DOWNTO 0) := (others => '0');
    signal counter_prsc_prvw_i : std_logic_vector((PRESCALE_FACTOR_WIDTH)*64 -1 DOWNTO 0) := (others => '0');


    type counter_array is array (9-1 downto 0) of std_logic_vector(64*RATE_COUNTER_WIDTH-1 downto 0);
    signal cnt_before_prsc     : counter_array := (others => (others => '0'));
    signal cnt_after_prsc      : counter_array := (others => (others => '0'));
    signal cnt_after_prsc_prvw : counter_array := (others => (others => '0'));
    signal cnt_post_dead_time  : counter_array := (others => (others => '0'));

    signal begin_lumi_per_del1 : std_logic ; -- delayed signal by one clk_x9 period




begin

    process (clk_x9)
    begin
        if rising_edge(clk_x9)then
            l1a_latency_delay_x9 <= (unsigned(l1a_latency_delay)-1)*to_unsigned(9,4)-1; --TODO check the value!!!
        end if;
    end process;

    process (clk_x9)
    begin
        if rising_edge(clk_x9) then
            begin_lumi_per_del1 <=  begin_lumi_per;
        end if;
    end process;

    -- TODO process to store data
    store_cnt_p : process (clk_x9)
    begin
        if rising_edge(clk_x9) then
            if begin_lumi_per_del1 = '1' then
                cnt_before_prsc     <= counter_rate_bp_i  & cnt_before_prsc(8 downto 1);
                cnt_after_prsc      <= counter_rate_ap_i  & cnt_after_prsc(8 downto 1) ;
                cnt_after_prsc_prvw <= counter_rate_app_i & cnt_after_prsc_prvw(8 downto 1);
                cnt_post_dead_time  <= counter_rate_pdt_i & cnt_post_dead_time(8 downto 1);
            end if;
        end if;
    end process;

    outer_loop : for j in 0 to 8 generate
        inner_loop : for i in 0 to 63 generate
            rate_cnt_before_prescaler(64*j + i)        <= cnt_before_prsc(j)(RATE_COUNTER_WIDTH*(i+1)-1 downto RATE_COUNTER_WIDTH*i);
            rate_cnt_after_prescaler(64*j + i)         <= cnt_after_prsc(j)(RATE_COUNTER_WIDTH*(i+1)-1 downto RATE_COUNTER_WIDTH*i);
            rate_cnt_after_prescaler_preview(64*j + i) <= cnt_after_prsc_prvw(j)(RATE_COUNTER_WIDTH*(i+1)-1 downto RATE_COUNTER_WIDTH*i);
            rate_cnt_post_dead_time(64*j + i)          <= cnt_post_dead_time(j)(RATE_COUNTER_WIDTH*(i+1)-1 downto RATE_COUNTER_WIDTH*i);
        end generate;
    end generate;


    addr_encode_p : process (clk_x9)
        variable addr_cnt : unsigned(3 downto 0) := (others => '0');
    begin
        if rising_edge(clk_x9) then
            if addr_cnt < 8 then
                addr_cnt := addr_cnt + 1;
            else
                addr_cnt := (others => '0');
            end if;
            r_addr   <= std_logic_vector(addr_cnt);
            addr_int <= r_addr;
            w_addr   <= addr_int;
        end if;
    end process;


    bp_counter_l : for i in 0 to 63 generate
        bp_counter_i : entity work.algo_rate_counter_mem
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                sys_clk         => sys_clk,
                lhc_clk         => lhc_clk,
                clk_x9          => clk_x9,
                rst_x9          => rst_x9,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per_del1,
                algo_i          => algos_i(i),
                counter_i       => counter_rate_bp_i(RATE_COUNTER_WIDTH*(i+1) -1 downto RATE_COUNTER_WIDTH*i),
                counter_o       => counter_rate_bp_o(RATE_COUNTER_WIDTH*(i+1) -1 downto RATE_COUNTER_WIDTH*i)
            );
    end generate;



    -- xpm_memory_sdpram: Simple Dual Port RAM
    -- Xilinx Parameterized Macro, version 2020.1
    sdpram_cnt_before_prsc_i : xpm_memory_sdpram
        generic map (
            ADDR_WIDTH_A => 4, -- DECIMAL
            ADDR_WIDTH_B => 4, -- DECIMAL
            AUTO_SLEEP_TIME => 0, -- DECIMAL
            BYTE_WRITE_WIDTH_A => RATE_COUNTER_WIDTH*64, -- DECIMAL
            CASCADE_HEIGHT => 0, -- DECIMAL
            CLOCKING_MODE => "common_clock", -- String
            ECC_MODE => "no_ecc", -- String
            MEMORY_INIT_FILE => "none", -- String
            MEMORY_INIT_PARAM => "", -- String
            MEMORY_OPTIMIZATION => "true", -- String
            MEMORY_PRIMITIVE => "bram", -- String
            MEMORY_SIZE => RATE_COUNTER_WIDTH*64*2**4, -- DECIMAL
            MESSAGE_CONTROL => 0, -- DECIMAL
            READ_DATA_WIDTH_B => RATE_COUNTER_WIDTH*64, -- DECIMAL
            READ_LATENCY_B => 1, -- DECIMAL
            READ_RESET_VALUE_B => "0", -- String
            RST_MODE_A => "SYNC", -- String
            RST_MODE_B => "SYNC", -- String
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            USE_EMBEDDED_CONSTRAINT => 0, -- DECIMAL
            USE_MEM_INIT => 1, -- DECIMAL
            WAKEUP_TIME => "disable_sleep", -- String
            WRITE_DATA_WIDTH_A => RATE_COUNTER_WIDTH*64, -- DECIMAL
            WRITE_MODE_B => "read_first" -- String
        )
        port map (
            --dbiterrb => '0', -- 1-bit output: Status signal to indicate double bit error occurrence
            -- on the data output of port B.

            doutb => counter_rate_bp_i, -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            --sbiterrb => sbiterrb, -- 1-bit output: Status signal to indicate single bit error occurrence
            -- on the data output of port B.
            addra => w_addr, -- ADDR_WIDTH_A-bit input: Address for port A write operations.
            addrb => r_addr, -- ADDR_WIDTH_B-bit input: Address for port B read operations.
            clka => clk_x9, -- 1-bit input: Clock signal for port A. Also clocks port B when
            -- parameter CLOCKING_MODE is "common_clock".
            clkb => clk_x9, -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
            -- "independent_clock". Unused when parameter CLOCKING_MODE is
            -- "common_clock".
            dina => counter_rate_bp_o, -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            ena => '1', -- 1-bit input: Memory enable signal for port A. Must be high on clock
            -- cycles when write operations are initiated. Pipelined internally.
            enb => '1', -- 1-bit input: Memory enable signal for port B. Must be high on clock
            -- cycles when read operations are initiated. Pipelined internally.
            injectdbiterra => '0', -- 1-bit input: Controls double bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            injectsbiterra => '0', -- 1-bit input: Controls single bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            regceb => '1', -- 1-bit input: Clock Enable for the last register stage on the output
            -- data path.
            rstb => rst_x9, -- 1-bit input: Reset signal for the final port B output register
            -- stage. Synchronously resets output port doutb to the value specified
            -- by parameter READ_RESET_VALUE_B.
            sleep => '0', -- 1-bit input: sleep signal to enable the dynamic power saving feature.
            wea => "1" -- WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
            -- data port dina. 1 bit wide when word-wide writes are used. In
            -- byte-wide write configurations, each bit controls the writing one
            -- byte of dina to address addra. For example, to synchronously write
            -- only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
            -- 4'b0010.
        );
    -- End of xpm_memory_sdpram_inst instantiation


    ap_counter_l : for i in 0 to 63 generate
        ap_counter_i : entity work.algo_rate_counter_mem
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                sys_clk         => sys_clk,
                lhc_clk         => lhc_clk,
                clk_x9          => clk_x9,
                rst_x9          => rst_x9,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per_del1,
                algo_i          => algo_after_prescaler_s(i),
                counter_i       => counter_rate_ap_i(RATE_COUNTER_WIDTH*(i+1) -1 downto RATE_COUNTER_WIDTH*i),
                counter_o       => counter_rate_ap_o(RATE_COUNTER_WIDTH*(i+1) -1 downto RATE_COUNTER_WIDTH*i)
            );
    end generate;



    -- xpm_memory_sdpram: Simple Dual Port RAM
    -- Xilinx Parameterized Macro, version 2020.1
    sdpram_cnt_after_prsc_i : xpm_memory_sdpram
        generic map (
            ADDR_WIDTH_A => 4, -- DECIMAL
            ADDR_WIDTH_B => 4, -- DECIMAL
            AUTO_SLEEP_TIME => 0, -- DECIMAL
            BYTE_WRITE_WIDTH_A => RATE_COUNTER_WIDTH*64, -- DECIMAL
            CASCADE_HEIGHT => 0, -- DECIMAL
            CLOCKING_MODE => "common_clock", -- String
            ECC_MODE => "no_ecc", -- String
            MEMORY_INIT_FILE => "none", -- String
            MEMORY_INIT_PARAM => "", -- String
            MEMORY_OPTIMIZATION => "true", -- String
            MEMORY_PRIMITIVE => "bram", -- String
            MEMORY_SIZE => RATE_COUNTER_WIDTH*64*2**4, -- DECIMAL
            MESSAGE_CONTROL => 0, -- DECIMAL
            READ_DATA_WIDTH_B => RATE_COUNTER_WIDTH*64, -- DECIMAL
            READ_LATENCY_B => 1, -- DECIMAL
            READ_RESET_VALUE_B => "0", -- String
            RST_MODE_A => "SYNC", -- String
            RST_MODE_B => "SYNC", -- String
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            USE_EMBEDDED_CONSTRAINT => 0, -- DECIMAL
            USE_MEM_INIT => 1, -- DECIMAL
            WAKEUP_TIME => "disable_sleep", -- String
            WRITE_DATA_WIDTH_A => RATE_COUNTER_WIDTH*64, -- DECIMAL
            WRITE_MODE_B => "read_first" -- String
        )
        port map (
            --dbiterrb => '0', -- 1-bit output: Status signal to indicate double bit error occurrence
            -- on the data output of port B.

            doutb => counter_rate_ap_i, -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            --sbiterrb => sbiterrb, -- 1-bit output: Status signal to indicate single bit error occurrence
            -- on the data output of port B.
            addra => w_addr, -- ADDR_WIDTH_A-bit input: Address for port A write operations.
            addrb => r_addr, -- ADDR_WIDTH_B-bit input: Address for port B read operations.
            clka => clk_x9, -- 1-bit input: Clock signal for port A. Also clocks port B when
            -- parameter CLOCKING_MODE is "common_clock".
            clkb => clk_x9, -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
            -- "independent_clock". Unused when parameter CLOCKING_MODE is
            -- "common_clock".
            dina => counter_rate_ap_o, -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            ena => '1', -- 1-bit input: Memory enable signal for port A. Must be high on clock
            -- cycles when write operations are initiated. Pipelined internally.
            enb => '1', -- 1-bit input: Memory enable signal for port B. Must be high on clock
            -- cycles when read operations are initiated. Pipelined internally.
            injectdbiterra => '0', -- 1-bit input: Controls double bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            injectsbiterra => '0', -- 1-bit input: Controls single bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            regceb => '1', -- 1-bit input: Clock Enable for the last register stage on the output
            -- data path.
            rstb => rst_x9, -- 1-bit input: Reset signal for the final port B output register
            -- stage. Synchronously resets output port doutb to the value specified
            -- by parameter READ_RESET_VALUE_B.
            sleep => '0', -- 1-bit input: sleep signal to enable the dynamic power saving feature.
            wea => "1" -- WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
            -- data port dina. 1 bit wide when word-wide writes are used. In
            -- byte-wide write configurations, each bit controls the writing one
            -- byte of dina to address addra. For example, to synchronously write
            -- only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
            -- 4'b0010.
        );
    -- End of xpm_memory_sdpram_inst instantiation


    app_counter_l : for i in 0 to 63 generate
        app_counter_i : entity work.algo_rate_counter_mem
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                sys_clk         => sys_clk,
                lhc_clk         => lhc_clk,
                clk_x9          => clk_x9,
                rst_x9          => rst_x9,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per_del1,
                algo_i          => algo_after_prescaler_preview_s(i),
                counter_i       => counter_rate_app_i(RATE_COUNTER_WIDTH*(i+1) -1 downto RATE_COUNTER_WIDTH*i),
                counter_o       => counter_rate_app_o(RATE_COUNTER_WIDTH*(i+1) -1 downto RATE_COUNTER_WIDTH*i)
            );
    end generate;



    -- xpm_memory_sdpram: Simple Dual Port RAM
    -- Xilinx Parameterized Macro, version 2020.1
    sdpram_cnt_after_prsc_prvw_i : xpm_memory_sdpram
        generic map (
            ADDR_WIDTH_A => 4, -- DECIMAL
            ADDR_WIDTH_B => 4, -- DECIMAL
            AUTO_SLEEP_TIME => 0, -- DECIMAL
            BYTE_WRITE_WIDTH_A => RATE_COUNTER_WIDTH*64, -- DECIMAL
            CASCADE_HEIGHT => 0, -- DECIMAL
            CLOCKING_MODE => "common_clock", -- String
            ECC_MODE => "no_ecc", -- String
            MEMORY_INIT_FILE => "none", -- String
            MEMORY_INIT_PARAM => "", -- String
            MEMORY_OPTIMIZATION => "true", -- String
            MEMORY_PRIMITIVE => "bram", -- String
            MEMORY_SIZE => RATE_COUNTER_WIDTH*64*2**4, -- DECIMAL
            MESSAGE_CONTROL => 0, -- DECIMAL
            READ_DATA_WIDTH_B => RATE_COUNTER_WIDTH*64, -- DECIMAL
            READ_LATENCY_B => 1, -- DECIMAL
            READ_RESET_VALUE_B => "0", -- String
            RST_MODE_A => "SYNC", -- String
            RST_MODE_B => "SYNC", -- String
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            USE_EMBEDDED_CONSTRAINT => 0, -- DECIMAL
            USE_MEM_INIT => 1, -- DECIMAL
            WAKEUP_TIME => "disable_sleep", -- String
            WRITE_DATA_WIDTH_A => RATE_COUNTER_WIDTH*64, -- DECIMAL
            WRITE_MODE_B => "read_first" -- String
        )
        port map (
            --dbiterrb => '0', -- 1-bit output: Status signal to indicate double bit error occurrence
            -- on the data output of port B.

            doutb => counter_rate_app_i, -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            --sbiterrb => sbiterrb, -- 1-bit output: Status signal to indicate single bit error occurrence
            -- on the data output of port B.
            addra => w_addr, -- ADDR_WIDTH_A-bit input: Address for port A write operations.
            addrb => r_addr, -- ADDR_WIDTH_B-bit input: Address for port B read operations.
            clka => clk_x9, -- 1-bit input: Clock signal for port A. Also clocks port B when
            -- parameter CLOCKING_MODE is "common_clock".
            clkb => clk_x9, -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
            -- "independent_clock". Unused when parameter CLOCKING_MODE is
            -- "common_clock".
            dina => counter_rate_app_o, -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            ena => '1', -- 1-bit input: Memory enable signal for port A. Must be high on clock
            -- cycles when write operations are initiated. Pipelined internally.
            enb => '1', -- 1-bit input: Memory enable signal for port B. Must be high on clock
            -- cycles when read operations are initiated. Pipelined internally.
            injectdbiterra => '0', -- 1-bit input: Controls double bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            injectsbiterra => '0', -- 1-bit input: Controls single bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            regceb => '1', -- 1-bit input: Clock Enable for the last register stage on the output
            -- data path.
            rstb => rst_x9, -- 1-bit input: Reset signal for the final port B output register
            -- stage. Synchronously resets output port doutb to the value specified
            -- by parameter READ_RESET_VALUE_B.
            sleep => '0', -- 1-bit input: sleep signal to enable the dynamic power saving feature.
            wea => "1" -- WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
            -- data port dina. 1 bit wide when word-wide writes are used. In
            -- byte-wide write configurations, each bit controls the writing one
            -- byte of dina to address addra. For example, to synchronously write
            -- only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
            -- 4'b0010.
        );
    -- End of xpm_memory_sdpram_inst instantiation


    --------------------------------------------------------------------------------------------------------------------------------------------
    ----------------------------------------------POST DESD TIME RATE COUNTER-------------------------------------------------------------------
    --------------------------------------------------------------------------------------------------------------------------------------------

    delay_element : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH => 64,
            MAX_DELAY  => MAX_DELAY*9
        )
        port map(
            clk    => clk_x9,
            rst    => rst_x9,
            data_i => algos_i,
            data_o => algos_delayed,
            delay  => std_logic_vector(l1a_latency_delay_x9)
        );


    pdt_counter_l : for i in 0 to 63 generate
        pdt_counter_i : entity work.algo_rate_counter_pdt_mem
            generic map(
                COUNTER_WIDTH => RATE_COUNTER_WIDTH
            )
            port map(
                sys_clk         => sys_clk,
                lhc_clk         => lhc_clk,
                clk_x9          => clk_x9,
                rst_x9          => rst_x9,
                sres_counter    => '0',
                store_cnt_value => begin_lumi_per_del1,
                l1a             => l1a,
                algo_del_i      => algos_delayed(i),
                counter_i       => counter_rate_pdt_i(RATE_COUNTER_WIDTH*(i+1) -1 downto RATE_COUNTER_WIDTH*i),
                counter_o       => counter_rate_pdt_o(RATE_COUNTER_WIDTH*(i+1) -1 downto RATE_COUNTER_WIDTH*i)
            );
    end generate;



    -- xpm_memory_sdpram: Simple Dual Port RAM
    -- Xilinx Parameterized Macro, version 2020.1
    sdpram_cnt_pdt_i : xpm_memory_sdpram
        generic map (
            ADDR_WIDTH_A => 4, -- DECIMAL
            ADDR_WIDTH_B => 4, -- DECIMAL
            AUTO_SLEEP_TIME => 0, -- DECIMAL
            BYTE_WRITE_WIDTH_A => RATE_COUNTER_WIDTH*64, -- DECIMAL
            CASCADE_HEIGHT => 0, -- DECIMAL
            CLOCKING_MODE => "common_clock", -- String
            ECC_MODE => "no_ecc", -- String
            MEMORY_INIT_FILE => "none", -- String
            MEMORY_INIT_PARAM => "", -- String
            MEMORY_OPTIMIZATION => "true", -- String
            MEMORY_PRIMITIVE => "bram", -- String
            MEMORY_SIZE => RATE_COUNTER_WIDTH*64*2**4, -- DECIMAL
            MESSAGE_CONTROL => 0, -- DECIMAL
            READ_DATA_WIDTH_B => RATE_COUNTER_WIDTH*64, -- DECIMAL
            READ_LATENCY_B => 1, -- DECIMAL
            READ_RESET_VALUE_B => "0", -- String
            RST_MODE_A => "SYNC", -- String
            RST_MODE_B => "SYNC", -- String
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            USE_EMBEDDED_CONSTRAINT => 0, -- DECIMAL
            USE_MEM_INIT => 1, -- DECIMAL
            WAKEUP_TIME => "disable_sleep", -- String
            WRITE_DATA_WIDTH_A => RATE_COUNTER_WIDTH*64, -- DECIMAL
            WRITE_MODE_B => "read_first" -- String
        )
        port map (
            --dbiterrb => '0', -- 1-bit output: Status signal to indicate double bit error occurrence
            -- on the data output of port B.

            doutb => counter_rate_pdt_i, -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            --sbiterrb => sbiterrb, -- 1-bit output: Status signal to indicate single bit error occurrence
            -- on the data output of port B.
            addra => w_addr, -- ADDR_WIDTH_A-bit input: Address for port A write operations.
            addrb => r_addr, -- ADDR_WIDTH_B-bit input: Address for port B read operations.
            clka => clk_x9, -- 1-bit input: Clock signal for port A. Also clocks port B when
            -- parameter CLOCKING_MODE is "common_clock".
            clkb => clk_x9, -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
            -- "independent_clock". Unused when parameter CLOCKING_MODE is
            -- "common_clock".
            dina => counter_rate_pdt_o, -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            ena => '1', -- 1-bit input: Memory enable signal for port A. Must be high on clock
            -- cycles when write operations are initiated. Pipelined internally.
            enb => '1', -- 1-bit input: Memory enable signal for port B. Must be high on clock
            -- cycles when read operations are initiated. Pipelined internally.
            injectdbiterra => '0', -- 1-bit input: Controls double bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            injectsbiterra => '0', -- 1-bit input: Controls single bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            regceb => '1', -- 1-bit input: Clock Enable for the last register stage on the output
            -- data path.
            rstb => rst_x9, -- 1-bit input: Reset signal for the final port B output register
            -- stage. Synchronously resets output port doutb to the value specified
            -- by parameter READ_RESET_VALUE_B.
            sleep => '0', -- 1-bit input: sleep signal to enable the dynamic power saving feature.
            wea => "1" -- WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
            -- data port dina. 1 bit wide when word-wide writes are used. In
            -- byte-wide write configurations, each bit controls the writing one
            -- byte of dina to address addra. For example, to synchronously write
            -- only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
            -- 4'b0010.
        );
    -- End of xpm_memory_sdpram_inst instantiation


    prescaler_l : for i in 0 to 63 generate
        prescaler_i : entity work.algo_pre_scaler_mem
            generic map(
                PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
                PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
            )
            port map(
                clk_x9              => clk_x9,
                rst_x9              => rst_x9,
                sres_counter        => '0',
                algo_i              => algos_i(i),
                update_factor_pulse => '0',
                prescale_factor     => prescale_factor,
                prescaled_algo_o    => algo_after_prescaler_s(i),
                counter_i           => counter_prsc_i((PRESCALE_FACTOR_WIDTH)*(i+1)-1 downto (PRESCALE_FACTOR_WIDTH)*i),
                counter_o           => counter_prsc_o((PRESCALE_FACTOR_WIDTH)*(i+1)-1 downto (PRESCALE_FACTOR_WIDTH)*i)
            );

    end generate;

    -- xpm_memory_sdpram: Simple Dual Port RAM
    -- Xilinx Parameterized Macro, version 2020.1
    sdpram_prescaler_i : xpm_memory_sdpram
        generic map (
            ADDR_WIDTH_A => 4, -- DECIMAL
            ADDR_WIDTH_B => 4, -- DECIMAL
            AUTO_SLEEP_TIME => 0, -- DECIMAL
            BYTE_WRITE_WIDTH_A => (PRESCALE_FACTOR_WIDTH)*64, -- DECIMAL
            CASCADE_HEIGHT => 0, -- DECIMAL
            CLOCKING_MODE => "common_clock", -- String
            ECC_MODE => "no_ecc", -- String
            MEMORY_INIT_FILE => "none", -- String
            MEMORY_INIT_PARAM => "", -- String
            MEMORY_OPTIMIZATION => "true", -- String
            MEMORY_PRIMITIVE => "bram", -- String
            MEMORY_SIZE => (PRESCALE_FACTOR_WIDTH)*64*2**4, -- DECIMAL
            MESSAGE_CONTROL => 0, -- DECIMAL
            READ_DATA_WIDTH_B => (PRESCALE_FACTOR_WIDTH)*64, -- DECIMAL
            READ_LATENCY_B => 1, -- DECIMAL
            READ_RESET_VALUE_B => "0", -- String
            RST_MODE_A => "SYNC", -- String
            RST_MODE_B => "SYNC", -- String
            SIM_ASSERT_CHK => 1, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            USE_EMBEDDED_CONSTRAINT => 0, -- DECIMAL
            USE_MEM_INIT => 1, -- DECIMAL
            WAKEUP_TIME => "disable_sleep", -- String
            WRITE_DATA_WIDTH_A => (PRESCALE_FACTOR_WIDTH)*64, -- DECIMAL
            WRITE_MODE_B => "read_first" -- String
        )
        port map (
            --dbiterrb => '0', -- 1-bit output: Status signal to indicate double bit error occurrence
            -- on the data output of port B.

            doutb =>  counter_prsc_i, -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            --sbiterrb => sbiterrb, -- 1-bit output: Status signal to indicate single bit error occurrence
            -- on the data output of port B.
            addra => w_addr, -- ADDR_WIDTH_A-bit input: Address for port A write operations.
            addrb => r_addr, -- ADDR_WIDTH_B-bit input: Address for port B read operations.
            clka => clk_x9, -- 1-bit input: Clock signal for port A. Also clocks port B when
            -- parameter CLOCKING_MODE is "common_clock".
            clkb => clk_x9, -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
            -- "independent_clock". Unused when parameter CLOCKING_MODE is
            -- "common_clock".
            dina => counter_prsc_o, -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            ena => '1', -- 1-bit input: Memory enable signal for port A. Must be high on clock
            -- cycles when write operations are initiated. Pipelined internally.
            enb => '1', -- 1-bit input: Memory enable signal for port B. Must be high on clock
            -- cycles when read operations are initiated. Pipelined internally.
            injectdbiterra => '0', -- 1-bit input: Controls double bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            injectsbiterra => '0', -- 1-bit input: Controls single bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            regceb => '1', -- 1-bit input: Clock Enable for the last register stage on the output
            -- data path.
            rstb => rst_x9, -- 1-bit input: Reset signal for the final port B output register
            -- stage. Synchronously resets output port doutb to the value specified
            -- by parameter READ_RESET_VALUE_B.
            sleep => '0', -- 1-bit input: sleep signal to enable the dynamic power saving feature.
            wea => "1" -- WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
            -- data port dina. 1 bit wide when word-wide writes are used. In
            -- byte-wide write configurations, each bit controls the writing one
            -- byte of dina to address addra. For example, to synchronously write
            -- only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
            -- 4'b0010.
        );
    -- End of xpm_memory_sdpram_inst instantiation

    prescaler_preview_l : for i in 0 to 63 generate
        prescaler_i : entity work.algo_pre_scaler_mem
            generic map(
                PRESCALE_FACTOR_WIDTH => PRESCALE_FACTOR_WIDTH,
                PRESCALE_FACTOR_INIT  => PRESCALE_FACTOR_INIT
            )
            port map(
                clk_x9              => clk_x9,
                rst_x9              => rst_x9,
                sres_counter        => '0',
                algo_i              => algos_i(i),
                update_factor_pulse => '0',
                prescale_factor     => prescale_factor_preview,
                prescaled_algo_o    => algo_after_prescaler_preview_s(i),
                counter_i           => counter_prsc_prvw_i((PRESCALE_FACTOR_WIDTH)*(i+1)-1 downto (PRESCALE_FACTOR_WIDTH)*i),
                counter_o           => counter_prsc_prvw_o((PRESCALE_FACTOR_WIDTH)*(i+1)-1 downto (PRESCALE_FACTOR_WIDTH)*i)
            );

    end generate;

    -- xpm_memory_sdpram: Simple Dual Port RAM
    -- Xilinx Parameterized Macro, version 2020.1
    sdpram_prescaler_preview_i : xpm_memory_sdpram
        generic map (
            ADDR_WIDTH_A => 4, -- DECIMAL
            ADDR_WIDTH_B => 4, -- DECIMAL
            AUTO_SLEEP_TIME => 0, -- DECIMAL
            BYTE_WRITE_WIDTH_A => (PRESCALE_FACTOR_WIDTH)*64, -- DECIMAL
            CASCADE_HEIGHT => 0, -- DECIMAL
            CLOCKING_MODE => "common_clock", -- String
            ECC_MODE => "no_ecc", -- String
            MEMORY_INIT_FILE => "none", -- String
            MEMORY_INIT_PARAM => "", -- String
            MEMORY_OPTIMIZATION => "true", -- String
            MEMORY_PRIMITIVE => "bram", -- String
            MEMORY_SIZE => (PRESCALE_FACTOR_WIDTH)*64*2**4, -- DECIMAL
            MESSAGE_CONTROL => 0, -- DECIMAL
            READ_DATA_WIDTH_B => (PRESCALE_FACTOR_WIDTH)*64, -- DECIMAL
            READ_LATENCY_B => 1, -- DECIMAL
            READ_RESET_VALUE_B => "0", -- String
            RST_MODE_A => "SYNC", -- String
            RST_MODE_B => "SYNC", -- String
            SIM_ASSERT_CHK => 1, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            USE_EMBEDDED_CONSTRAINT => 0, -- DECIMAL
            USE_MEM_INIT => 1, -- DECIMAL
            WAKEUP_TIME => "disable_sleep", -- String
            WRITE_DATA_WIDTH_A => (PRESCALE_FACTOR_WIDTH)*64, -- DECIMAL
            WRITE_MODE_B => "read_first" -- String
        )
        port map (
            --dbiterrb => '0', -- 1-bit output: Status signal to indicate double bit error occurrence
            -- on the data output of port B.

            doutb =>  counter_prsc_prvw_i, -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            --sbiterrb => sbiterrb, -- 1-bit output: Status signal to indicate single bit error occurrence
            -- on the data output of port B.
            addra => w_addr, -- ADDR_WIDTH_A-bit input: Address for port A write operations.
            addrb => r_addr, -- ADDR_WIDTH_B-bit input: Address for port B read operations.
            clka => clk_x9, -- 1-bit input: Clock signal for port A. Also clocks port B when
            -- parameter CLOCKING_MODE is "common_clock".
            clkb => clk_x9, -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
            -- "independent_clock". Unused when parameter CLOCKING_MODE is
            -- "common_clock".
            dina => counter_prsc_prvw_o, -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            ena => '1', -- 1-bit input: Memory enable signal for port A. Must be high on clock
            -- cycles when write operations are initiated. Pipelined internally.
            enb => '1', -- 1-bit input: Memory enable signal for port B. Must be high on clock
            -- cycles when read operations are initiated. Pipelined internally.
            injectdbiterra => '0', -- 1-bit input: Controls double bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            injectsbiterra => '0', -- 1-bit input: Controls single bit error injection on input data when
            -- ECC enabled (Error injection capability is not available in
            -- "decode_only" mode).
            regceb => '1', -- 1-bit input: Clock Enable for the last register stage on the output
            -- data path.
            rstb => rst_x9, -- 1-bit input: Reset signal for the final port B output register
            -- stage. Synchronously resets output port doutb to the value specified
            -- by parameter READ_RESET_VALUE_B.
            sleep => '0', -- 1-bit input: sleep signal to enable the dynamic power saving feature.
            wea => "1" -- WRITE_DATA_WIDTH_A-bit input: Write enable vector for port A input
            -- data port dina. 1 bit wide when word-wide writes are used. In
            -- byte-wide write configurations, each bit controls the writing one
            -- byte of dina to address addra. For example, to synchronously write
            -- only bits [15-8] of dina when WRITE_DATA_WIDTH_A is 32, wea would be
            -- 4'b0010.
        );
    -- End of xpm_memory_sdpram_inst instantiation


    algo_after_prescaler         <= algo_after_prescaler_s;
    algo_after_prescaler_preview <= algo_after_prescaler_preview_s;



end architecture RTL;


-- TODO Rework the rate counter out, mostly the indexing
-- TODO Clock domain crossing (ipbus_clk to clk_x9), actually it is the bram that is too large
-- TODO add prescale factors from ipbus regs/memory