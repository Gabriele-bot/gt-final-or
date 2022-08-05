
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



package FinOR_pkg is
    
    constant N_BOARD     : natural := 12;
    constant N_SLR       : natural := 4;
    constant INPUT_LINKS : natural := 24;
    constant N_TRIGG     : natural := 8;
    
    
    type data_arr is array (INPUT_LINKS - 1 downto 0) of std_logic_vector(64*9-1 downto 0);
    type mask_arr is array (N_TRIGG     - 1 downto 0) of std_logic_vector(64*9-1 downto 0);
    
    
end package FinOR_pkg;

package body FinOR_pkg is
    
end package body FinOR_pkg;
