library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.FinOR_pkg.all;
use work.P2GT_finor_pkg.all;

entity Mask is
    generic(
        NR_ALGOS : natural := 64*9
    );
    port(
        clk         : in std_logic;
        algos_in    : in std_logic_vector(NR_ALGOS - 1 downto 0);
        masks       : in mask_arr;
        trigger_out : out std_logic_vector(N_TRIGG -1 downto 0)
    );
end entity Mask;

architecture RTL of Mask is
    
    signal trigger_s : std_logic_vector(N_TRIGG -1 downto 0) := (others => '0');
    
begin
    
    trigger_out_l : for i in 0 to N_TRIGG -1 generate
        trigger_s(i) <= or (algos_in and masks(i));
    end generate;
    
    process(clk)
    begin
        if rising_edge(clk) then
            trigger_out <= trigger_s;
        end if;
    end process;

end architecture RTL;
