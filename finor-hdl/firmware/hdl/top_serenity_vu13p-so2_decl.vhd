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
    constant LB_ADDR_WIDTH : integer := 10;

    -- Clock setup
    constant CLOCK_COMMON_RATIO : integer               := 36;
    constant CLOCK_RATIO        : integer               := 9;
    constant CLOCK_AUX_DIV      : clock_divisor_array_t := (36, 9, 4); -- Dividers of CLOCK_COMMON_RATIO * 40 MHz

    constant SLINK_CONF : slink_conf_array_t := (
        others => kNoSlink
    );

    constant REGION_CONF : region_conf_array_t := (
        -------------------- SLR0 RIGHT -------------------- 
        --0      => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR0
        --1      => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_o_kind => gty25),     --input algo-bits links SLR0 & output algo-bits SLR0
        --2      => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR0
        0      => (gty25, buf, no_fmt, buf, gty25),
        1      => (gty25, buf, no_fmt, buf, gty25),
        2      => (gty25, buf, no_fmt, buf, gty25),
        --3      => kDummyRegion,         -- Not Used
        -------------------- SLR1 RIGHT --------------------
        4      => kDummyRegion,         -- HighSpeedBus
        5      => kDummyRegion,         -- PCIe, AXI & TCDS
        --6      => (mgt_i_kind => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_o_kind => gty25), -- output algo-bits SLR0
        --7      => (mgt_i_kind => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_o_kind => gty25), -- output algo-bits SLR2
        6      => (gty25, buf, no_fmt, buf, gty25),
        7      => (gty25, buf, no_fmt, buf, gty25),
        -------------------- SLR2 RIGHT --------------------
        8      => kDummyRegion,         -- Not used
        9      => (gty25, buf, no_fmt, buf, gty25),
        10     => (gty25, buf, no_fmt, buf, gty25),
        11     => (gty25, buf, no_fmt, buf, gty25),
        --9      => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR2
        --10     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_o_kind => gty25),     --input algo-bits links SLR2 & output algo-bits SLR2
        --11     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR2
        -------------------- SLR3 RIGHT --------------------
        12     => (gty25, buf, no_fmt, buf, gty25),
        13     => (gty25, buf, no_fmt, buf, gty25),
        14     => (gty25, buf, no_fmt, buf, gty25),
        --12     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR3
        --13     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_o_kind => gty25),     --input algo-bits links SLR3 & output algo-bits SLR3
        --14     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR3
        15     => kDummyRegion,         -- Unconnected
        -- Cross-chip------------------------------------------
        -------------------- SLR3 LEFT --------------------
        16     => kDummyRegion,         -- Unconnected
        17     => (gty25, buf, no_fmt, buf, gty25),
        18     => (gty25, buf, no_fmt, buf, gty25),
        19     => (gty25, buf, no_fmt, buf, gty25),
        --17     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR3
        --18     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR3
        --19     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR3
        -------------------- SLR2 LEFT --------------------
        20     => (gty25, buf, no_fmt, buf, gty25),
        21     => (gty25, buf, no_fmt, buf, gty25),
        22     => (gty25, buf, no_fmt, buf, gty25),
        --20     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR2
        --21     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR2
        --22     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR2
        23     => kDummyRegion,         -- Not Used
        -------------------- SLR1 LEFT --------------------
        24     => (gty25, buf, no_fmt, buf, gty25),
        --24     => (mgt_i_kind => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_o_kind => gty25), --output trigger-bits link SLR1
        25     => kDummyRegion,         -- Not Used 
        26     => kDummyRegion,         -- Unconnected
        27     => kDummyRegion,         -- HighSpeedBus
        -------------------- SLR0 LEFT --------------------
        28     => kDummyRegion,         -- Not Used
        29     => (gty25, buf, no_fmt, buf, gty25),
        30     => (gty25, buf, no_fmt, buf, gty25),
        31     => (gty25, buf, no_fmt, buf, gty25),
        --29     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR0
        --30     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR0
        --31     => (mgt_i_kind => gty25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_o_kind => no_mgt), --input algo-bits links SLR0
        others => kDummyRegion
    );

end emp_project_decl;

