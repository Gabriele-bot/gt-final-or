-- Description:
-- Package for constant and type definitions of in P2GT FinalOR firmware.

-- Created by Gabriele Bortolato 14-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware) 

-- Version-history:
-- GB : make some modification on the conversion
-- GB : 20-07-2022 merge various packages

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package P2GT_finor_pkg is

    -- =======================================================================================================
    -- GT FinalOR definitions
    -- =======================================================================================================
    constant N_BOARD     : natural := 12;
    constant N_SLR       : natural := 4;
    constant INPUT_LINKS : natural := 24;
    constant MON_REG     : natural := 6;
    constant N_TRIGG     : natural := 8;
    
    
    type data_arr is array (INPUT_LINKS - 1 downto 0) of std_logic_vector(64*9-1 downto 0);
    type mask_arr is array (N_TRIGG     - 1 downto 0) of std_logic_vector(64*9-1 downto 0);
    

    -- ================= PRE-SCALERS =========================================================================
    -- Definitions for prescalers (P2GT FinalOR)

    -- fixed point prescale factor format, e.g. 2 digits (!) in 32 bits integer
    -- Example input factor --> 1001, real factor --> 10.01
    constant PRESCALE_FACTOR_FRACTION_DIGITS : integer := 2 ;
    constant PRESCALE_FACTOR_WIDTH           : integer := 24;

    -- Initialization prescale factor value (note the decimal format with two digits)
    constant PRESCALE_FACTOR_INIT_VALUE : real := 1.00;

    -- Convertion in integer and std_logic_vector
    constant PRESCALE_FACTOR_INIT_VALUE_INTEGER : integer               := integer(PRESCALE_FACTOR_INIT_VALUE * real(10**PRESCALE_FACTOR_FRACTION_DIGITS));
    constant PRESCALE_FACTOR_INIT_VALUE_UNSGND  : unsigned(31 downto 0) := to_unsigned(PRESCALE_FACTOR_INIT_VALUE_INTEGER, 32);
    --     constant PRESCALE_FACTOR_INIT : ipb_regs_array(0 to 511) := (others => PRESCALE_FACTOR_INIT_VALUE_VEC);

    -- Prescaler increment (1*10**fraction_digits)
    constant PRESCALER_INCR : unsigned(31 downto 0) := to_unsigned(10**PRESCALE_FACTOR_FRACTION_DIGITS, 32);

    type prescale_factor_array is array (9*64-1 downto 0) of std_logic_vector(PRESCALE_FACTOR_WIDTH-1 downto 0);


    -- =======================================================================================================

    -- Algo board parameters
    --constant N_BOARD         : natural := 1;
    --constant N_SLR_PER_BOARD : natural := 3 ;
    --constant N_ALGOS_PER_SLR : natural := 64;
    --constant N_ALGOS         : natural := N_BOARD * N_SLR_PER_BOARD * N_ALGOS_PER_SLR;
    --constant N_ALGOS         : natural := 1152;


    -- ================= RATE COUNTERS ========================================================================
    -- Definitions for rate counters (P2GT FinalOR)

    constant RATE_COUNTER_WIDTH         : natural := 32;

    type rate_counter_array is array (9*64-1 downto 0) of std_logic_vector(RATE_COUNTER_WIDTH-1 downto 0);


end package;
