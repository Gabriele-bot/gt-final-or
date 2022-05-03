
-- Description: Output mask for the different trigger types

-- Created by Gabriele Bortolato 21-04-2022


-- Resources utilization (8 trigger types)
-- |       | Synth |  Impl |
-- |-------|-------|-------|
-- | LUT   |  2648 |  2648 |
-- | FF    |  8    |  8    |
----------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.FinOR_pkg.all;

entity Mask is
    generic(
        NR_ALGOS : natural := 64*9;
        NR_TRIGG : natural := N_TRIGG
    );
    port(
        clk         : in std_logic;
        algos_in    : in std_logic_vector(NR_ALGOS - 1 downto 0);
        masks       : in mask_arr;
        trigger_out : out std_logic_vector(NR_TRIGG -1 downto 0)
    );
end entity Mask;

architecture RTL of Mask is
    
    signal trigger_s : std_logic_vector(NR_TRIGG -1 downto 0) := (others => '0');
    
begin
    
    trigger_out_l : for i in 0 to NR_TRIGG -1 generate
        trigger_s(i) <= or (algos_in and masks(i));
    end generate;
    
    process(clk)
    begin
        if rising_edge(clk) then
            trigger_out <= trigger_s;
        end if;
    end process;

end architecture RTL;
