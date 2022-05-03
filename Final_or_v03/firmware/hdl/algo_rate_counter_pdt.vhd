
-- Desription:
-- Rate counter post dead time for algorithms in in P2GT FinalOR
-- Output synchronized with sys_clk, to prevent wrong counter values when reading via PCIe.

-- Created by Gabriele Bortolato 21-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware)

-- Version-history:
-- GB : make some modifications
-- GB : changed delay element architecture
-- GB : moved delay element outsite (vectorized it)

-- Resources utilization
-- |       | Synth |  Impl |
-- |-------|-------|-------|
-- | Carry |  5    |  5    |
-- | LUT   |  35   |  35   |
-- | FF    |  65   |  65   |
----------------------------


library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pkg.all;

entity algo_rate_counter_pdt is
   generic( 
      COUNTER_WIDTH : integer := 32
   );
   port( 
      sys_clk          : in     std_logic;
      lhc_clk          : in     std_logic;
      lhc_rst          : in     std_logic;
      sres_counter     : in     std_logic;
      store_cnt_value  : in     std_logic;
      l1a              : in     std_logic;
      algo_del_i       : in     std_logic;
      counter_o        : out    std_logic_vector(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0') -- init value (for simulation)
   );
end algo_rate_counter_pdt;

architecture rtl of algo_rate_counter_pdt is
    
    signal counter       : unsigned(COUNTER_WIDTH   DOWNTO 0) := (others => '0');
    signal counter_int   : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal limit         : std_logic := '0';
   

begin
    

    counter_p: process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            if sres_counter = '1' or store_cnt_value = '1' then
                if (limit = '0' and algo_del_i = '1'  and l1a = '1') then
                    counter <= to_unsigned(1, counter'length); -- this (re)sets the counter value to 1 if there occurs a trigger just in the 'store_cnt_value' clk cycle
                else
                    counter <= (others => '0'); -- clear counter with synchr. reset and store_cnt_value (which is begin of lumi section)
                end if;
            elsif (limit = '0' and algo_del_i = '1' and l1a = '1') then
                counter <= counter + 1;
            end if;
        end if;
    end process counter_p;

    compare_p: process (counter)
    begin
        if (counter(COUNTER_WIDTH) = '1') then
            limit <= '1';
        else
            limit <= '0';
        end if;
    end process compare_p;

    store_int_p: process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            if store_cnt_value = '1' then
                counter_int <= counter(COUNTER_WIDTH-1 DOWNTO 0); -- "store" counter value internally for read access with store_cnt_value (which is begin of lumi section)
            end if;
        end if;
    end process store_int_p;

    counter_o <= std_logic_vector(counter_int);


end architecture rtl;
