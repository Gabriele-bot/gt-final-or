
-- Desription:
-- Rate counter for algorithms in in P2GT FinalOR
-- Output synchronized with sys_clk, to prevent wrong counter values when reading via PCIe.

-- Created by Gabriele Bortolato 14-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware)

-- Version-history:
-- GB : make some modifications


library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity algo_rate_counter is
    generic(
        COUNTER_WIDTH : integer := 32
    );
    port(
        sys_clk          : in     std_logic; 
        clk              : in     std_logic;
        sres_counter     : in     std_logic;
        store_cnt_value  : in     std_logic;
        algo_i           : in     std_logic;
        counter_o        : out    std_logic_vector(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0') -- init value (for simulation)
    );
end algo_rate_counter;

architecture rtl of algo_rate_counter is

    constant counter_end : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '1'); -- counter stops at this value
    signal counter       : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal counter_int   : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal limit         : std_logic := '0';

begin
    counter_p: process (clk)
    begin
        if rising_edge(clk) then
            if sres_counter = '1' or store_cnt_value = '1' then
                if (limit = '0' and algo_i = '1') then
                    counter <= to_unsigned(1, counter'length); -- this (re)sets the counter value to 1 if there occurs a trigger just in the 'store_cnt_value' clk cycle
                else
                    counter <= (others => '0'); -- clear counter with synchr. reset and store_cnt_value (which is begin of lumi section)
                end if;
            elsif limit = '1' then
                counter <= counter_end;
            elsif (limit = '0' and algo_i = '1') then
                counter <= counter + 1;
            end if;
        end if;
    end process counter_p;

    compare_p: process (counter)
    begin
        if (counter = counter_end) then
            limit <= '1';
        else
            limit <= '0';
        end if;
    end process compare_p;

    store_int_p: process (clk)
    begin
        if rising_edge(clk) then
            if store_cnt_value = '1' then
                counter_int <= counter; -- "store" counter value internally for read access with store_cnt_value (which is begin of lumi section)
            end if;
        end if;
    end process store_int_p;

    counter_o <= std_logic_vector(counter_int);

end architecture rtl;

-- TODO ask which clk to use
