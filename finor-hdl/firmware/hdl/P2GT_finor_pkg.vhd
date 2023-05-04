-- Description:
-- Package for constant and type definitions of in P2GT FinalOR firmware.

-- Created by Gabriele Bortolato 14-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware) 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_data_types.all;
use work.emp_ttc_decl.all;

package P2GT_finor_pkg is
    
    
    -- =======================================================================================================
    -- GT Final-OR definitions
    -- =======================================================================================================
    constant N_BOARD                : integer := 12;
    constant N_SLR_PER_BOARD        : integer := 4;
    constant N_MONITOR_SLR          : integer := 2;
    constant INPUT_R_LINKS_SLR      : integer := 12;
    constant INPUT_L_LINKS_SLR      : integer := 12;
    constant INPUT_LINKS_SLR        : integer := INPUT_R_LINKS_SLR + INPUT_L_LINKS_SLR;
    constant INPUT_QUADS            : integer := 3 + 3;
    constant N_TRIGG                : integer := 8;
    constant BEGIN_LUMI_SEC_BIT     : integer := 18;
    constant BEGIN_LUMI_SEC_BIT_SIM : integer := 3;
    constant MAX_DELAY_PDT          : integer := 511; -- corresponding to ~12.78 us  (40  MHz domain)
    constant MAX_CTRS_DELAY_360     : integer := 511; -- corresponding to ~1.42  us  (360 MHz domain)
    constant SLR_CROSSING_LATENCY   : integer := 9;
    constant FINOR_LATENCY          : integer := 3;
    constant N_SLR_ALGOS            : integer := 576;
    constant N_ALGOS                : integer := N_SLR_ALGOS * N_MONITOR_SLR;
    constant DESER_OUT_REG          : boolean := FALSE;

    type ChannelSystemMap is array (natural range <>) of natural;
    type QuadSystemMap    is array (natural range <>) of natural;
    constant SLRn0_channels : ChannelSystemMap(INPUT_LINKS_SLR - 1 downto 0)   := (127,126,125,124,123,122,121,120,119,118,117,116,11,10,9,8,7,6,5,4,3,2,1,0);
    constant SLRn1_channels : ChannelSystemMap(INPUT_LINKS_SLR - 1 downto 0)   := (91,90,89,88,87,86,85,84,83,82,81,80,47,46,45,44,43,42,41,40,39,38,37,36);
    constant SLRn0_quads    : ChannelSystemMap(INPUT_LINKS_SLR/4 - 1 downto 0) := (31,30,29,2,1,0  );
    constant SLRn1_quads    : ChannelSystemMap(INPUT_LINKS_SLR/4 - 1 downto 0) := (22,21,20,11,10,9);
    
    constant OUTPUT_channel : natural := 96;
    constant OUTPUT_quad    : natural := 24;
    
    constant OUTPUT_algo_channels : ChannelSystemMap(6 - 1 downto 0)  := (29,28,27,26,25,24);
    constant OUTPUT_algo_quads    : QuadSystemMap   (2 - 1 downto 0)  := (7,6); 
    constant DEBUG_channels       : ChannelSystemMap(2 - 1 downto 0)  := (31,30);
    constant DEBUG_quad           : natural                           := 7; 


    type data_arr is array (INPUT_LINKS_SLR - 1 downto 0) of std_logic_vector(LWORD_WIDTH*9 - 1 downto 0);
    type mask_arr is array (N_TRIGG         - 1 downto 0) of std_logic_vector(N_SLR_ALGOS   - 1 downto 0);
    
    -- ================= COUTER TYPES ========================================================================
    
    type bctr_array is array (natural range <>) of bctr_t;
    
    subtype p2gt_ectr_t  is std_logic_vector(47 downto 0);
    subtype p2gt_octr_t  is std_logic_vector(47 downto 0);
    subtype p2gt_bctr_t  is std_logic_vector(11 downto 0);
    subtype p2gt_lsctr_t is std_logic_vector(31 downto 0);

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

    type prescale_factor_array is array (natural range <>) of std_logic_vector(PRESCALE_FACTOR_WIDTH-1 downto 0);

    -- ================= RATE COUNTERS ========================================================================
    -- Definitions for rate counters (P2GT FinalOR)

    constant RATE_COUNTER_WIDTH         : natural := 32;

    type rate_counter_array is array (natural range <>) of std_logic_vector(RATE_COUNTER_WIDTH-1 downto 0);


end package;
