
-- Desription:
-- Rate counter post dead time for algorithms in in P2GT FinalOR
-- Output synchronized with sys_clk, to prevent wrong counter values when reading via PCIe.

-- Created by Gabriele Bortolato 21-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware)

-- Version-history:
-- GB : make some modifications
-- GB : changed delay element architecture


library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.math_pkg.all;

entity algo_rate_counter_pdt is
   generic( 
      COUNTER_WIDTH : integer := 32;
      MAX_DELAY     : integer := 128
   );
   port( 
      sys_clk          : in     std_logic;
      lhc_clk          : in     std_logic;
      lhc_rst          : in     std_logic;
      sres_counter     : in     std_logic;
      store_cnt_value  : in     std_logic;
      l1a              : in     std_logic;
      delay            : in     std_logic_vector(log2c(MAX_DELAY)-1 downto 0);
      algo_i           : in     std_logic;
      counter_o        : out    std_logic_vector(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0') -- init value (for simulation)
   );
end algo_rate_counter_pdt;

architecture rtl of algo_rate_counter_pdt is
    
    constant counter_end : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '1'); -- counter stops at this value
    signal counter       : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal counter_int   : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal limit         : std_logic := '0';
    
    signal algo_delayed : std_logic;
    signal algo_o       : std_logic;
    signal valid_o      : std_logic;

begin
    
    algo_delay_i: entity work.delay_element
        generic map(
            MAX_DELAY  => MAX_DELAY
        )
        port map(
            clk         => lhc_clk,
            rst         => lhc_rst,
            data_i      => algo_i,
            data_o      => algo_o,
            valid_o     => valid_o,
            delay       => delay
        );
        
    algo_delayed <= algo_o and valid_o;

    counter_p: process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            if sres_counter = '1' or store_cnt_value = '1' then
                if (limit = '0' and algo_delayed = '1'  and l1a = '1') then
                    counter <= to_unsigned(1, counter'length); -- this (re)sets the counter value to 1 if there occurs a trigger just in the 'store_cnt_value' clk cycle
                else
                    counter <= (others => '0'); -- clear counter with synchr. reset and store_cnt_value (which is begin of lumi section)
                end if;
            elsif limit = '1' then
                counter <= counter_end;
            elsif (limit = '0' and algo_delayed = '1' and l1a = '1') then
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

    store_int_p: process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            if store_cnt_value = '1' then
                counter_int <= counter; -- "store" counter value internally for read access with store_cnt_value (which is begin of lumi section)
            end if;
        end if;
    end process store_int_p;

    counter_o <= std_logic_vector(counter_int);


end architecture rtl;