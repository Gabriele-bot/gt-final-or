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
        0      => kDummyRegion,         -- PCIe, AXI & TCDS
        1      => (mgt_protocol_in => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_protocol_out => csp25), --output to TCDS2
        2      => (mgt_protocol_in => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_protocol_out => csp25), --output to TCDS2
        3      => (mgt_protocol_in => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_protocol_out => csp25), --output to TCDS2
        -------------------- SLR1 RIGHT --------------------
        4      => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- backup algo-bits links SLR1 [0:511]
        5      => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- backup algo-bits links SLR1 [0:511]
        6      => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- backup algo-bits links SLR1 [0:511]
        7      => kDummyRegion,
        -------------------- SLR2 RIGHT --------------------
        8      => (mgt_protocol_in => csp25 , buf_i_kind => buf   , fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- backup algo-bits links SLR2 [512:1023]
        9      => (mgt_protocol_in => csp25 , buf_i_kind => buf   , fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- backup algo-bits links SLR2 [512:1023]
        10     => (mgt_protocol_in => csp25 , buf_i_kind => buf   , fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- backup algo-bits links SLR2 [512:1023]
        11     => (mgt_protocol_in => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf   , mgt_protocol_out => csp25 ), -- output algo-bits to scouting
        -------------------- SLR3 RIGHT --------------------
        12     => (mgt_protocol_in => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf   , mgt_protocol_out => csp25), -- output algo-bits to scouting
        13     => (mgt_protocol_in => csp25 , buf_i_kind => buf   , fmt_kind => no_fmt, buf_o_kind => buf   , mgt_protocol_out => csp25), -- backup algo-bits links SLR3 [1024:1535] & output algo-bits to scouting
        14     => (mgt_protocol_in => csp25 , buf_i_kind => buf   , fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- backup algo-bits links SLR3 [1024:1535]
        15     => (mgt_protocol_in => csp25 , buf_i_kind => buf   , fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- backup algo-bits links SLR3 [1024:1535]
        -------------------- SLR3 LEFT --------------------
        16     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR3 [1024:1535]
        17     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR3 [1024:1535]
        18     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR3 [1024:1535]
        19     => kDummyRegion,
        -------------------- SLR2 LEFT --------------------
        20     => kDummyRegion,
        21     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR2 [512:1023]
        22     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR2 [512:1023]
        23     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR2 [512:1023]
        -------------------- SLR1 LEFT --------------------
        24     => kDummyRegion,
        25     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR1 [0:511]
        26     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR1 [0:511]
        27     => (mgt_protocol_in => csp25, buf_i_kind => buf, fmt_kind => no_fmt, buf_o_kind => no_buf, mgt_protocol_out => no_mgt), -- input algo-bits links SLR1 [0:511]
        -------------------- SLR0 LEFT --------------------
        28     => (mgt_protocol_in => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_protocol_out => csp25), -- External condition to algo-boards
        29     => (mgt_protocol_in => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_protocol_out => csp25), -- External condition to algo-boards
        30     => (mgt_protocol_in => no_mgt, buf_i_kind => no_buf, fmt_kind => no_fmt, buf_o_kind => buf, mgt_protocol_out => csp25), -- External condition to algo-boards
        31     => kDummyRegion,         -- DAQ
        others => kDummyRegion
    );

end emp_project_decl;

