--=================================================================
--Link data align/misframed packets
--Alignemnt check is performed comparing the matadata of all unmasked links
--Links are considered aligned if UNMASKED metadata are all equal (xor-like)
--=================================================================
library ieee;
use ieee.std_logic_1164.all;

use work.emp_data_types.all;
use work.emp_ttc_decl.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Link_align_check is
    generic(
        NR_LINKS : natural := 3
    );
    port(
        clk360            : in  std_logic;
        rst360            : in  std_logic;
        link_mask         : in  std_logic_vector(NR_LINKS - 1 downto 0);
        metadata          : in  std_logic_vector(NR_LINKS - 1 downto 0);
        rst_err           : in  std_logic;
        align_err_o       : out std_logic
    );
end entity Link_align_check;

architecture RTL of Link_align_check is

    signal align_err : std_logic := '0';

begin

    align_check_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if align_err = '1' then
                if rst_err = '1' or rst360 = '1' then
                    align_err <= '0';
                end if;
            else
                align_err <= not ((nor (link_mask and metadata)) or (and (not(link_mask) or metadata)));
            end if;
        end if;
    end process align_check_p;

    align_err_o <= align_err;

end architecture RTL;
