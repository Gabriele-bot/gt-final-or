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
        clk360      : in  std_logic;
        rst360      : in  std_logic;
        link_mask   : in  std_logic_vector(NR_LINKS - 1 downto 0);
        metadata    : in  std_logic_vector(NR_LINKS - 1 downto 0);  -- input vector to check
        rst_err     : in  std_logic;
        align_err_o : out std_logic
    );
end entity Link_align_check;

architecture RTL of Link_align_check is

    signal align_err : std_logic := '0';

begin

    -- The check is divided in two paths:
    -- ===============================
    -- FIRST PATH
    -- ===============================
    -- The first path checks if the unmasked metadata bits are ALL equal to '1' 
    -- The logic operation is the logical OR of the negated linkmask against the metadata logic vector,
    -- this ties the masked bits to '1' and the unmasked to whatever they are. Finally, the the reduced NAND is computed
    -- such that '0' is obtained only if the complete vector is made of '1' 
    -- ===============================
    -- SECOND PATH
    -- ===============================
    -- The second path checks if the unmasked metadata bits are all equal to '0' 
    -- The logic operation is the logical AND of the linkmask against the metadata logic vector,
    -- this ties the masked bits to '0' and the unmasked to whatever they are. Finally the the reduced OR is computed
    -- such that '0' is obtained only if the complete vector is made of '0'
    -- ===============================
    -- RESULT
    -- ===============================
    -- The result is the AND of the two paths, if both of them fail the check it means that the unmasked input vector is not coherent.  
    align_check_p : process(clk360)
        variable check_for_ones  : std_logic_vector(NR_LINKS - 1 downto 0);
        variable check_for_zeros : std_logic_vector(NR_LINKS - 1 downto 0);
    begin
        if rising_edge(clk360) then
            if align_err = '1' then     -- to un-latch the flag, one of the two resets must be asserted
                if rst_err = '1' or rst360 = '1' then
                    align_err <= '0';
                end if;
            else
                check_for_ones  := (not (link_mask) or metadata);
                check_for_zeros := (link_mask and metadata);
                align_err       <= (or check_for_zeros) and (nand check_for_ones);
            end if;
        end if;
    end process align_check_p;

    align_err_o <= align_err;

end architecture RTL;
