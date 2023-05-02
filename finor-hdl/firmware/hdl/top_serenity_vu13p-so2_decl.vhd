-- emp_project_decl for the VU13P Daughter Card (full) example design
--
-- Defines constants for the whole project
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.emp_framework_decl.all;
use work.emp_device_types.all;
use work.emp_slink_types.all;


package emp_project_decl is

  constant PAYLOAD_REV : std_logic_vector(31 downto 0) := X"12345678";

  -- Latency buffer size
  constant LB_ADDR_WIDTH   : integer := 10;

  -- Clock setup
  constant CLOCK_COMMON_RATIO : integer               := 36;
  constant CLOCK_RATIO        : integer               := 9;
  constant CLOCK_AUX_DIV      : clock_divisor_array_t := (36, 9, 4); -- Dividers of CLOCK_COMMON_RATIO * 40 MHz
  
  constant SLINK_CONF : slink_conf_array_t := (
  others      => kNoSlink
  );


  constant REGION_CONF : region_conf_array_t := (
    0      => (gty25, buf, no_fmt, buf, gty25), --algo links SLR0
    1      => (gty25, buf, no_fmt, buf, gty25), --algo links SLR0
    2      => (gty25, buf, no_fmt, buf, gty25), --algo links SLR0
    3      => kDummyRegion,             -- Not Used
    4      => kDummyRegion,             -- HighSpeedBus
    5      => kDummyRegion,             -- PCIe, AXI & TCDS
    6      => (gty25, buf, no_fmt, buf, gty25), --output algo-bits links SLR1
    7      => (gty25, buf, no_fmt, buf, gty25), --output algo-bits links SLR1
    8      => kDummyRegion,             -- Not used
    9      => (gty25, buf, no_fmt, buf, gty25), --algo links SLR2
    10     => (gty25, buf, no_fmt, buf, gty25), --algo links SLR2
    11     => (gty25, buf, no_fmt, buf, gty25), --algo links SLR2
    12     => kDummyRegion,             -- Not used
    13     => kDummyRegion,             -- Not Used
    14     => kDummyRegion,             -- Not Used
    15     => kDummyRegion,             -- Unconnected
    -- Cross-chip
    16     => kDummyRegion,             -- Unconnected
    17     => kDummyRegion,             -- Not used
    18     => kDummyRegion,             -- Not Used
    19     => kDummyRegion,             -- Not Used
    20     => (gty25, buf, no_fmt, buf, gty25), --algo links SLR2
    21     => (gty25, buf, no_fmt, buf, gty25), --algo links SLR2
    22     => (gty25, buf, no_fmt, buf, gty25), --algo links SLR2
    23     => kDummyRegion,             -- Not Used
    24     => (gty25, buf, no_fmt, buf, gty25), --output trigger-bits link SLR1
    25     => kDummyRegion,             -- Not Used
    26     => kDummyRegion,             -- Unconnected
    27     => kDummyRegion,             -- HighSpeedBus
    28     => kDummyRegion,             -- Not Used
    29     => (gty25, buf, no_fmt, buf, gty25), --algo links SLR0
    30     => (gty25, buf, no_fmt, buf, gty25), --algo links SLR0
    31     => (gty25, buf, no_fmt, buf, gty25), --algo links SLR0
    others => kDummyRegion
    );

end emp_project_decl;

