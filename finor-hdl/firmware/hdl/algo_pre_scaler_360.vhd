
-- Description:
-- Prescalers for algorithms in P2GT FinalOR with fractional prescale values in fixed point notation. (base 10)
-- Prescaled algos delayed by 1 clock cycle 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.P2GT_finor_pkg.all;

entity algo_pre_scaler_360 is
    generic(
        PRESCALE_FACTOR_WIDTH : integer;
        PRESCALE_FACTOR_INIT  : std_logic_vector(31 DOWNTO 0) := X"00000064"; --1.00
        SIM : boolean := false
    );
    port(
        clk                         : in std_logic;
        sres_counter                : in std_logic;
        algo_i                      : in std_logic;
        request_update_factor_pulse : in std_logic;
        update_factor_pulse         : in std_logic;
        prescale_factors            : in prescale_factor_array(8 downto 0);
        frame_ctr                   : in std_logic_vector(3 downto 0);
        prescaled_algo_o            : out std_logic;
        -- output for simulation
        prescaled_algo_cnt_sim      : out natural := 0;
        algo_cnt_sim                : out natural := 0
    );
end algo_pre_scaler_360;

architecture rtl of algo_pre_scaler_360 is

    constant ZERO : unsigned(PRESCALE_FACTOR_WIDTH-1 downto 0) := (others => '0');
    constant INCR : unsigned(PRESCALE_FACTOR_WIDTH-1 downto 0) := PRESCALER_INCR(PRESCALE_FACTOR_WIDTH-1 downto 0);

    signal prescale_factors_int : prescale_factor_array(8 downto 0) := (others => PRESCALE_FACTOR_INIT(PRESCALE_FACTOR_WIDTH-1 downto 0));

    type counter_arr is array (8 downto 0) of unsigned(PRESCALE_FACTOR_WIDTH-1 downto 0);

    signal counters             : counter_arr := (others => (others => '0'));
    signal factors              : counter_arr := (others => (others => '0'));
    signal algo_passes          : std_logic_vector(8 downto 0) := (others => '0');
    
    signal algo_del             : std_logic;

    signal frame_ctr_integer    : integer range 0 to 8;
    signal frame_ctr_del        : integer range 0 to 8;
    
    signal update_factor_pulse_del : std_logic_vector(8 downto 0);
    
    signal sres_ctr_del : std_logic_vector(8 downto 0);
    signal strch_sres   : std_logic;
    
begin
    
    update_factor_pulse_del(0) <= update_factor_pulse;
    process (clk)
    begin
        if rising_edge(clk) then
            update_factor_pulse_del(8 downto 1) <= update_factor_pulse_del(7 downto 0);
        end if;
    end process;

    frame_ctr_integer <= to_integer(unsigned(frame_ctr));
    process (clk)
    begin
        if rising_edge(clk) then
            frame_ctr_del <= frame_ctr_integer;
        end if;
    end process;

    gen_update_reg_l : for i in 0 to 8 generate
        prescale_factor_update_i: entity work.update_process
            generic map(
                WIDTH      => PRESCALE_FACTOR_WIDTH,
                INIT_VALUE => PRESCALE_FACTOR_INIT
            )
            port map(
                clk                  => clk,
                request_update_pulse => request_update_factor_pulse,
                update_pulse         => update_factor_pulse_del(i),
                data_i               => prescale_factors(i)(PRESCALE_FACTOR_WIDTH-1 downto 0),
                data_o               => prescale_factors_int(i)(PRESCALE_FACTOR_WIDTH-1 downto 0)
            );
        factors(i) <= unsigned(prescale_factors_int(i)(PRESCALE_FACTOR_WIDTH-1 downto 0));
    end generate;

    -- Comparing counter and factor
    gen_compare_l : for i in 0 to 8 generate
        compare_p: process(factors(i),counters(i))
        begin
            if (factors(i) = ZERO) then
                algo_passes(i) <= '0';
            elsif ((counters(i) + INCR) >= factors(i)) then
                algo_passes(i) <= '1';
            else
                algo_passes(i) <= '0';
            end if;
        end process;
    end generate;

    --compare_p: process(clk)
    --begin
    --    if rising_edge(clk) then
    --        if (factors(frame_ctr_integer) = ZERO) then
    --            algo_passes(frame_ctr_integer) <= '0';
    --            prescaled_algo_o <= '0';
    --        elsif ((counters(frame_ctr_integer) + INCR) >= factors(frame_ctr_integer)) then
    --            algo_passes(frame_ctr_integer) <= '1';
    --            prescaled_algo_o <= '1';
    --        else
    --            algo_passes(frame_ctr_integer) <= '0';
    --            prescaled_algo_o <= '0';
    --        end if;
    --    end if;
    --end process compare_p;
    
    sres_ctr_del(0) <= sres_counter;
    shreg_p: process(clk)
    begin
        if rising_edge(clk) then
            sres_ctr_del(8 downto 1) <= sres_ctr_del(7 downto 0);
        end if;
    end process shreg_p;
    strch_sres <= or sres_ctr_del;

    -- Counting algos, INCR is defined in the pre_scaler_pkg
    counter_p: process (clk)
    begin
        if rising_edge(clk) then
            if (strch_sres = '1' and algo_i = '0') then
                counters(frame_ctr_integer) <= (others => '0');
            elsif (strch_sres = '1' and algo_i = '1') then
                counters(frame_ctr_integer) <= INCR;
            elsif (algo_passes(frame_ctr_integer) = '1' and algo_i = '1') then
                counters(frame_ctr_integer) <= counters(frame_ctr_integer) + INCR - factors(frame_ctr_integer);
            elsif (algo_passes(frame_ctr_integer) = '0' and algo_i = '1') then
                counters(frame_ctr_integer) <= counters(frame_ctr_integer) + INCR;
            end if;
        end if;
    end process counter_p;

    -- Generating prescaled algos 
    -- prescale factor value = 0                      => no prescaled algos
    -- prescale factor value = 1.00 (with INCR = 100) => algo pass through

    -- SET the ouptus accordingly
    out_p: process(clk)
    begin
        if rising_edge(clk) then
            prescaled_algo_o <= algo_i and algo_passes(frame_ctr_integer);
        end if;
    end process out_p;


    -- Generating signals for simulation
    prescaled_algo_cnt_i: if SIM generate
        prescaled_algo_cnt_p: process (clk)
            type algo_cnt_t is array (8 downto 0) of natural;
            variable algo_cnt           : algo_cnt_t := (others => 0);
            variable prescaled_algo_cnt : algo_cnt_t := (others => 0);
        begin
            -- TODO ask if it is correct
            if falling_edge(clk) then           -- not sure on this one
                if sres_counter = '1' or update_factor_pulse = '1' then
                    prescaled_algo_cnt := (others => 0);
                    algo_cnt           := (others => 0);
                elsif algo_passes(frame_ctr_integer) = '0' and algo_i = '1' then
                    algo_cnt(frame_ctr_integer) := algo_cnt(frame_ctr_integer) + 1;
                elsif algo_passes(frame_ctr_integer) = '1' and algo_i = '1' then
                    algo_cnt(frame_ctr_integer) := algo_cnt(frame_ctr_integer) + 1;
                    prescaled_algo_cnt(frame_ctr_integer) := prescaled_algo_cnt(frame_ctr_integer) + 1;
                end if;
                algo_cnt_sim <= algo_cnt(frame_ctr_integer);
                prescaled_algo_cnt_sim <= prescaled_algo_cnt(frame_ctr_integer);
            end if;
        end process prescaled_algo_cnt_p;
    end generate prescaled_algo_cnt_i;

end architecture rtl;
