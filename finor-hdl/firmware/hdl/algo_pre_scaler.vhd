-- Description:
-- Prescalers for algorithms in P2GT FinalOR with fractional prescale values in fixed point notation.

-- Created by Gabriele Bortolato 14-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware) 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.P2GT_finor_pkg.all;

entity algo_pre_scaler is
    generic(
        PRESCALE_FACTOR_WIDTH : integer;
        PRESCALE_FACTOR_INIT  : std_logic_vector(31 DOWNTO 0) := X"00000064"; --1.00
        SIM                   : boolean                       := false
    );
    port(
        clk40                  : in  std_logic;
        rst40                  : in  std_logic;
        sres_counter           : in  std_logic;
        algo_i                 : in  std_logic;
        prescale_factor        : in  std_logic_vector(PRESCALE_FACTOR_WIDTH - 1 DOWNTO 0);
        prescaled_algo_o       : out std_logic;
        -- output for simulation
        prescaled_algo_cnt_sim : out natural := 0;
        algo_cnt_sim           : out natural := 0
    );
end algo_pre_scaler;

architecture rtl of algo_pre_scaler is

    constant ZERO : unsigned(PRESCALE_FACTOR_WIDTH - 1 downto 0) := (others => '0');
    constant INCR : unsigned(PRESCALE_FACTOR_WIDTH - 1 downto 0) := PRESCALER_INCR(PRESCALE_FACTOR_WIDTH - 1 downto 0);

    signal counter   : unsigned(PRESCALE_FACTOR_WIDTH - 1 downto 0) := (others => '0');
    signal factor    : unsigned(PRESCALE_FACTOR_WIDTH - 1 downto 0) := (others => '0');
    signal algo_pass : std_logic                                    := '0';

begin

    factor <= unsigned(prescale_factor);

    -- Comparing counter and factor
    compare_p : process(counter, factor)
    begin
        if (factor = ZERO) then
            algo_pass <= '0';
        elsif ((counter + INCR) >= factor) then
            algo_pass <= '1';
        else
            algo_pass <= '0';
        end if;
    end process compare_p;

    -- Counting algos, INCR is defined in the pre_scaler_pkg
    counter_p : process(clk40)
    begin
        if rising_edge(clk40) then
            if (sres_counter = '1' and algo_i = '0') then
                counter <= (others => '0');
            elsif (sres_counter = '1' and algo_i = '1') then
                counter <= INCR;
            elsif (algo_pass = '1' and algo_i = '1') then
                counter <= counter + INCR - factor;
            elsif (algo_pass = '0' and algo_i = '1') then
                counter <= counter + INCR;
            end if;
        end if;
    end process counter_p;

    -- SET the ouptus accordingly
    prescaled_algo_o <= algo_i and algo_pass;

    -- Generating signals for simulation
    prescaled_algo_cnt_i : if SIM generate
        prescaled_algo_cnt_p : process(clk40)
            variable algo_cnt           : natural := 0;
            variable prescaled_algo_cnt : natural := 0;
        begin
            if falling_edge(clk40) then -- not sure on this one
                if sres_counter = '1' then
                    prescaled_algo_cnt := 0;
                    algo_cnt           := 0;
                elsif algo_pass = '0' and algo_i = '1' then
                    algo_cnt := algo_cnt + 1;
                elsif algo_pass = '1' and algo_i = '1' then
                    algo_cnt           := algo_cnt + 1;
                    prescaled_algo_cnt := prescaled_algo_cnt + 1;
                end if;
                algo_cnt_sim           <= algo_cnt;
                prescaled_algo_cnt_sim <= prescaled_algo_cnt;
            end if;
        end process prescaled_algo_cnt_p;
    end generate prescaled_algo_cnt_i;

end architecture rtl;

