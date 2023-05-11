--=================================================================
--Data Link Merger
--Simple merge perforemed with a bitwise OR
--If necessary links can be masked and treated as LWORD_NULL (others => '0', 0, 0, 0, 0, 0)
--=================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_data_types.all;

use work.P2GT_finor_pkg.all;

entity Link_merger is
    generic(
        NR_LINKS : natural := 3
    );
    port(
        clk360    : in  std_logic;
        rst360    : in  std_logic;
        link_mask : in  std_logic_vector(NR_LINKS - 1 downto 0);
        d         : in  ldata(NR_LINKS - 1 downto 0); -- data in
        q         : out lword                         -- data out
    );
end entity Link_merger;

architecture RTL of Link_merger is

    type data_input_t is array (NR_LINKS - 1 downto 0) of std_logic_vector(LWORD_WIDTH - 1 downto 0);
    type data_trnsp_t is array (LWORD_WIDTH - 1 downto 0) of std_logic_vector(NR_LINKS - 1 downto 0);
    signal d_data            : data_input_t;
    signal d_valids          : std_logic_vector(NR_LINKS - 1 downto 0);
    signal d_starts_of_orbit : std_logic_vector(NR_LINKS - 1 downto 0);
    signal d_starts          : std_logic_vector(NR_LINKS - 1 downto 0);
    signal d_lasts           : std_logic_vector(NR_LINKS - 1 downto 0);
    signal d_strobes         : std_logic_vector(NR_LINKS - 1 downto 0);
    signal data_mapped       : data_trnsp_t;
    signal q_int             : lword;

    --signal valid_error             : std_logic;
    --signal start_of_orbit_error    : std_logic;
    --signal start_error             : std_logic;
    --signal last_error              : std_logic;
    --signal allign_error            : std_logic;

    signal or_valid          : std_logic;
    signal or_start_of_orbit : std_logic;
    signal or_start          : std_logic;
    signal or_last           : std_logic;

begin

    data_fill_i : for i in 0 to NR_LINKS - 1 generate
        d_data(i)            <= d(i).data;
        d_valids(i)          <= d(i).valid;
        d_starts_of_orbit(i) <= d(i).start_of_orbit;
        d_starts(i)          <= d(i).start;
        d_lasts(i)           <= d(i).last;
        d_strobes(i)         <= d(i).strobe;
    end generate;

    -- TODO what to do if a link is masked??
    --valid_error <= xor d_valids;
    --start_of_orbit_error <= xor d_starts_of_orbit;
    --start_error <= xor d_starts;
    --last_error  <= xor d_lasts;

    --allign_error <= valid_error or start_of_orbit_error or start_error or last_error;

    mapping_i : for i in 0 to LWORD_WIDTH - 1 generate
        mapping_j : for j in 0 to NR_LINKS - 1 generate
            data_mapped(i)(j) <= d_data(j)(i) and d_valids(j) and link_mask(j);
        end generate;
    end generate;

    --Merge
    Merge_i : for k in 0 to LWORD_WIDTH - 1 generate
        q_int.data(k) <= or (data_mapped(k));
    end generate;
    q_int.valid          <= or (d_valids          and link_mask);
    q_int.start_of_orbit <= or (d_starts_of_orbit and link_mask);
    q_int.start          <= or (d_starts          and link_mask);
    q_int.last           <= or (d_lasts           and link_mask);
    q_int.strobe         <= or (d_strobes         and link_mask);

    process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                q <= LWORD_NULL;
            else
                q <= q_int;
            end if;
        end if;
    end process;

end architecture RTL;
