library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.FinOR_pkg.all;
use work.P2GT_finor_pkg.all;

entity FirstOR is
    generic(
        NR_LINKS : natural := 24
    );
    port(
        --lhc_clk  : in std_logic;
        --lhc_rst  : in std_logic;
        data_in  : in data_arr;
        data_out : out std_logic_vector(64*9-1 downto 0)
    );
end entity FirstOR;

architecture RTL of FirstOR is
    
    signal data_out_s : std_logic_vector(64*9-1 downto 0);

    type data_matrix is array (64*9-1 downto 0) of std_logic_vector(NR_LINKS-1 downto 0);
    signal data_mapped : data_matrix ;

begin

    mapping_i : for i in 0 to 64*9-1 generate
        mapping_j : for j in 0 to NR_LINKS -1 generate
            data_mapped(i)(j) <= data_in(j)(i);
        end generate;
    end generate;

    or_proc : for k in 0 to 64*9-1 generate
        process(data_mapped(k))
        begin
            data_out_s(k) <= or data_mapped(k);
        end process;
    end generate;   
    
    --process(data_in)
    --    variable temp :std_logic_vector(64*9-1 downto 0) := (others => '0');
    --begin
    --    for i in 0 to NR_LINKS-1 loop
    --            temp := temp or data_in(i);
    --    end loop;
    --    data_out_s <= temp;
    --end process;
    
    data_out <= data_out_s;

end architecture RTL;
