-- Description:
-- Package for constant and type definitions of in P2GT FinalOR firmware.

-- Created by Gabriele Bortolato 15-03-2022

-- Version-history:

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pkg.all;
use work.pre_scaler_pkg.all;


package P2GT_monitor_pkg is

    -- Algo board parameters
    --constant N_BOARD         : natural := 1;
    --constant N_SLR_PER_BOARD : natural := 3 ;
    --constant N_ALGOS_PER_SLR : natural := 64;
    --constant N_ALGOS         : natural := N_BOARD * N_SLR_PER_BOARD * N_ALGOS_PER_SLR;
    --constant N_ALGOS         : natural := 1152;


    -- Rate conunter
    constant RATE_COUNTER_WIDTH         : natural := 32;
    
    type prsc_fct_array is array (8 downto 0) of std_logic_vector(PRESCALE_FACTOR_WIDTH- 1 downto 0);
    type cnt_rate_array is array (8 downto 0) of std_logic_vector(RATE_COUNTER_WIDTH   - 1 downto 0);
    
    type rate_counter_array is array (9*64-1 downto 0) of std_logic_vector(RATE_COUNTER_WIDTH-1 downto 0);
    
    type prescale_factor_array is array (9*64-1 downto 0) of std_logic_vector(PRESCALE_FACTOR_WIDTH-1 downto 0);

end package P2GT_monitor_pkg;

package body P2GT_monitor_pkg is

end package body P2GT_monitor_pkg;
