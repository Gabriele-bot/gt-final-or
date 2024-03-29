-- emp_project_decl for simulation
--
-- Defines constants for the whole device
--
-- Alessandro Thea, Apr 2018

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

    constant REGION_CONF : region_conf_array_t := (
        -- Uncomment to trigger the gt
        0      => (no_mgt, buf, no_fmt, buf, no_mgt),
        1      => (no_mgt, buf, no_fmt, buf, no_mgt),
        2      => (no_mgt, buf, no_fmt, buf, no_mgt),
        3      => (no_mgt, buf, no_fmt, buf, no_mgt),
        4      => kDummyRegion,             -- HighSpeedBus
        5      => kDummyRegion,             -- PCIe, AXI & TCDS
        6      => (no_mgt, buf, no_fmt, buf, no_mgt),
        7      => (no_mgt, buf, no_fmt, buf, no_mgt),
        8      => (no_mgt, buf, no_fmt, buf, no_mgt),
        9      => (no_mgt, buf, no_fmt, buf, no_mgt),
        10     => (no_mgt, buf, no_fmt, buf, no_mgt),
        11     => (no_mgt, buf, no_fmt, buf, no_mgt),
        12     => (no_mgt, buf, no_fmt, buf, no_mgt),
        13     => (no_mgt, buf, no_fmt, buf, no_mgt),
        14     => (no_mgt, buf, no_fmt, buf, no_mgt),
        15     => kDummyRegion,             -- Unconnected
        -- Cross-chip
        16     => kDummyRegion,             -- Unconnected
        17     => (no_mgt, buf, no_fmt, buf, no_mgt),
        18     => (no_mgt, buf, no_fmt, buf, no_mgt),
        19     => (no_mgt, buf, no_fmt, buf, no_mgt),
        20     => (no_mgt, buf, no_fmt, buf, no_mgt),
        21     => (no_mgt, buf, no_fmt, buf, no_mgt),
        22     => (no_mgt, buf, no_fmt, buf, no_mgt),
        23     => (no_mgt, buf, no_fmt, buf, no_mgt),
        24     => (no_mgt, buf, no_fmt, buf, no_mgt),
        25     => (no_mgt, buf, no_fmt, buf, no_mgt),
        26     => kDummyRegion,             -- Unconnected
        27     => kDummyRegion,             -- HighSpeedBus
        28     => (no_mgt, buf, no_fmt, buf, no_mgt),
        29     => (no_mgt, buf, no_fmt, buf, no_mgt),
        30     => (no_mgt, buf, no_fmt, buf, no_mgt),
        31     => (no_mgt, buf, no_fmt, buf, no_mgt),
        others => kDummyRegion
    );

    -- Specify slink channels to enable using the channel mask
    constant SLINK_CONF : slink_conf_array_t := (
        others      => kNoSlink
    );

end emp_project_decl;
