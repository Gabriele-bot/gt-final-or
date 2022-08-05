-- emp_project_decl for the VU13P Daughter Card (full) example design
--
-- Defines constants for the whole project
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.emp_framework_decl.all;
use work.emp_device_types.all;


package emp_project_decl is

  constant PAYLOAD_REV : std_logic_vector(31 downto 0) := X"12345678";

  -- Latency buffer size
  constant LB_ADDR_WIDTH   : integer := 10;

  -- Clock setup
  constant CLOCK_COMMON_RATIO : integer               := 36;
  constant CLOCK_RATIO        : integer               := 9;
  constant CLOCK_AUX_DIV      : clock_divisor_array_t := (36, 9, 4); -- Dividers of CLOCK_COMMON_RATIO * 40 MHz


  constant REGION_CONF : region_conf_array_t := (
    0      => (gty25, buf, no_fmt, buf, gty25),
    1      => (gty25, buf, no_fmt, buf, gty25),
    2      => (gty25, buf, no_fmt, buf, gty25),
    3      => (gty25, buf, no_fmt, buf, gty25),
    4      => kDummyRegion,             -- HighSpeedBus
    5      => kDummyRegion,             -- PCIe, AXI & TCDS
    6      => (gty25, buf, no_fmt, buf, gty25),
    7      => (gty25, buf, no_fmt, buf, gty25),
    8      => (gty25, buf, no_fmt, buf, gty25),
    9      => (gty25, buf, no_fmt, buf, gty25),
    10     => (gty25, buf, no_fmt, buf, gty25),
    11     => (gty25, buf, no_fmt, buf, gty25),
    12     => (gty25, buf, no_fmt, buf, gty25),
    13     => (gty25, buf, no_fmt, buf, gty25),
    14     => (gty25, buf, no_fmt, buf, gty25),
    15     => kDummyRegion,             -- Unconnected
    -- Cross-chip
    16     => kDummyRegion,             -- Unconnected
    17     => (gty25, buf, no_fmt, buf, gty25),
    18     => (gty25, buf, no_fmt, buf, gty25),
    19     => (gty25, buf, no_fmt, buf, gty25),
    20     => (gty25, buf, no_fmt, buf, gty25),
    21     => (gty25, buf, no_fmt, buf, gty25),
    22     => (gty25, buf, no_fmt, buf, gty25),
    23     => (gty25, buf, no_fmt, buf, gty25),
    24     => (gty25, buf, no_fmt, buf, gty25),
    25     => (gty25, buf, no_fmt, buf, gty25),
    26     => kDummyRegion,             -- Unconnected
    27     => kDummyRegion,             -- HighSpeedBus
    28     => (gty25, buf, no_fmt, buf, gty25),
    29     => (gty25, buf, no_fmt, buf, gty25),
    30     => (gty25, buf, no_fmt, buf, gty25),
    31     => (gty25, buf, no_fmt, buf, gty25),
    others => kDummyRegion
    );

end emp_project_decl;

