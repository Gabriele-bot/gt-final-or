library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.pre_scaler_pkg.all;

entity algo_pre_scaler_mem is
    generic(
        PRESCALE_FACTOR_WIDTH : integer;
        PRESCALE_FACTOR_INIT  : unsigned(31 DOWNTO 0)
    );
    port(
        clk_x9              : in  std_logic;
        rst_x9              : in  std_logic;
        sres_counter        : in  std_logic;
        algo_i              : in  std_logic;
        update_factor_pulse : in  std_logic;
        prescale_factor     : in  std_logic_vector (PRESCALE_FACTOR_WIDTH-1 DOWNTO 0);
        prescaled_algo_o    : out std_logic;
        counter_i           : in  std_logic_vector (PRESCALE_FACTOR_WIDTH-1 DOWNTO 0)  := (others => '0');
        counter_o           : out std_logic_vector (PRESCALE_FACTOR_WIDTH-1 DOWNTO 0) := (others => '0')
    );
end entity algo_pre_scaler_mem;

architecture RTL of algo_pre_scaler_mem is

    constant ZERO : unsigned(PRESCALE_FACTOR_WIDTH-1 downto 0) := (others => '0');
    constant INCR : unsigned(PRESCALE_FACTOR_WIDTH-1 downto 0) := PRESCALER_INCR(PRESCALE_FACTOR_WIDTH-1 downto 0);

    signal counter_o_s : unsigned(PRESCALE_FACTOR_WIDTH-1 downto 0) := (others => '0');
    signal counter_i_s : unsigned(PRESCALE_FACTOR_WIDTH-1 downto 0) := (others => '0');
    signal factor      : unsigned(PRESCALE_FACTOR_WIDTH-1 downto 0) := PRESCALE_FACTOR_INIT(PRESCALE_FACTOR_WIDTH-1 downto 0);



    signal prescaled_algo_s : std_logic;


begin

    counter_i_s   <= unsigned(counter_i);
    factor        <= unsigned(prescale_factor);



    -- Comparing counter and factor
    compare_p: process (clk_x9)
    begin
        if rising_edge(clk_x9) then
            if rst_x9 = '1' then
                counter_o_s <= (others => '0');
            elsif (sres_counter = '1') or (update_factor_pulse = '1') then
                counter_o_s <= (others => '0');
            elsif ((counter_i_s + INCR) >= factor) then
                if algo_i = '1' then
                    --prescaled_algo_s <= '1';
                    counter_o_s <= counter_i_s + INCR - factor;
                else
                    --prescaled_algo_s <= '0';
                    counter_o_s <= counter_i_s;
                end if;
            else
                if algo_i = '1' then
                    --prescaled_algo_s <= '0';
                    counter_o_s <= counter_i_s + INCR;
                else
                    --prescaled_algo_s <= '0';
                    counter_o_s <= counter_i_s;
                end if;
            end if;
        end if;
    end process compare_p;

    counter_o <= std_logic_vector(counter_o_s);

    output_p : process (counter_i_s, factor, clk_x9, algo_i)
    begin
        if ((counter_i_s + INCR) >= factor) then
            if algo_i = '1' then
                prescaled_algo_s <= '1';
            else
                prescaled_algo_s <= '0';
            end if;
        else
            prescaled_algo_s <= '0';
        end if;

    end process output_p;

    -- Generating prescaled algos 
    -- prescale factor value = 0                      => no prescaled algos
    -- prescale factor value = 1.00 (with INCR = 100) => algo pass through
    --prescaled_algo_p: process (clk)
    --    variable algo_cnt : natural := 0; -- (?)
    --begin
    --    -- TODO ask if it is correct
    --    --if falling_edge(clk) then 
    --    if rising_edge(clk) then           -- not sure on this one
    --        if factor = ZERO then
    --            prescaled_algo_o <= '0';
    --        elsif limit = '1' and algo_i = '1' then
    --           prescaled_algo_o <= '1';
    --        else
    --            prescaled_algo_o <= '0';
    --        end if;
    --    end if;
    --end process prescaled_algo_p;

    -- SET the ouptus accordingly
    prescaled_algo_o <= prescaled_algo_s;

end architecture RTL;
