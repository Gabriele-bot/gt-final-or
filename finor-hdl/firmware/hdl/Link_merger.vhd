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
        clk_p : in std_logic;
        rst_p : in std_logic;
        d     : in   ldata(NR_LINKS - 1 downto 0);  -- data in
        q     : out  lword;  -- data out
    );
end entity Link_merger;

architecture RTL of Link_merger is

    type data_input_t is array (NR_LINKS - 1 downto 0) of std_logic_vector(63 downto 0);
    type data_trnsp_t is array (63 downto 0) of std_logic_vector(NR_LINKS - 1 downto 0);
    signal d_data      : data_input_t ;
    signal d_valids    : std_logic_vector(NR_LINKS - 1 downto 0);
    signal d_starts    : std_logic_vector(NR_LINKS - 1 downto 0);
    signal d_strobes   : std_logic_vector(NR_LINKS - 1 downto 0);
    signal data_mapped : data_trnsp_t ;
    signal q_int : lword;

begin

    data_fill_i : for i in 0 to NR_LINKS - 1 generate
        d_data(i)    <= d(i).data;
        d_valids(i)  <= d(i).valid;
        d_starts(i)  <= d(i).start;
        d_strobes(i) <= d(i).strobe;
    end generate;

    mapping_i : for i in 0 to 63 generate
        mapping_j : for j in 0 to NR_LINKS -1 generate
            data_mapped(i)(j) <= data_in(j)(i);
        end generate;
    end generate;

    Merge_i : for k in 0 to 63 generate
        q_int.data(k) <= or data_mapped(k);
    end generate;

    q_int.valid  <= or d_valids;
    q_int.start  <= or d_starts;
    q_int.strobe <= or d_strobes;


    process(clk_p)
    begin
        if rising_edge(clk_p) then
            q <= q_int;
        end if;
    end process;

end architecture RTL;
