--=================================================================
--Link data align/misframed packets
--Alignemnt check is performed comparing the matadata of all unmasked links
--Links are considered aligned if UNMASKED metadata are all equal (xor-like)
--=================================================================

-- link_mask   : masked links won't contribute to the aligment check coputation
-- metadata    : vector made of the specific link metadata (e.g. start_of_orbit), 
--               in total 4 different modules are instantited (start_of_orbit, start, last, valid)
-- align_err_o : latched aligment error flag, need to be reseted once is asserted
-- rst_err     : reset to unlatch the aligment error flag

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
    
    -- The check will evaluate if the unmasked metadata bits are all the same, e.g. Start of orbit is asserted at the same time.
    -- Masked bits won't contribute, thus they will be ingored.
    -- The check is divided in two paths, the first path checks if the metadata bits are ALL equal to '1', the second path checks
    -- if ALL bits are equal to '0'. If both checks fail it means that at least one link is misaligned (e.g. on link X the START 
    -- is asserted one clock cycle later with respect to the others). 
    -- ===============================
    -- FIRST PATH
    -- ===============================
    -- The first path checks if the unmasked metadata bits are ALL equal to '1' 
    -- The logic operation is the logical OR of the negated linkmask against the metadata logic vector,
    -- this ties the masked bits to '1' and the unmasked to whatever they are. Finally, the reduced NAND is computed
    -- such that '0' is obtained only if all bits are equal to '1', result is '1' otherwise 
    -- ===============================
    -- SECOND PATH
    -- ===============================
    -- The second path checks if the unmasked metadata bits are all equal to '0' 
    -- The logic operation is the logical AND of the linkmask against the metadata logic vector,
    -- this ties the masked bits to '0' and the unmasked to whatever they are. Finally the reduced OR is computed
    -- such that '0' is obtained only if all bits are equal to '0', result is '1' otherwise 
    -- ===============================
    -- RESULT
    -- ===============================
    -- The result is the AND of the two paths, if both of them fail the check it means that the unmasked input vector is not coherent. 
    
    -- ===============================
    -- EXAMPLE with 4 links
    -- ===============================
    -- We mask link 2 --> link_mask := "1011"
    -- All start are aligned:
    -- ===============================
    -- Clock cycle -1 = "0-00" --> check_for_ones  = not (1011) or 0-00 = "0100"
    -- Clock cycle 0  = "1-11" --> check_for_ones  = not (1011) or 1-11 = "1111"
    -- Clock cycle +1 = "0-00" --> check_for_ones  = not (1011) or 0-00 = "0100"
    -- In case of all ones (Clock Cycle 0) the NAND reduce is '0', '1' in the others
    -- Clock cycle -1 = "0-00" --> check_for_zeros = 1011 and 0-00 = "0000"
    -- Clock cycle 0  = "1-11" --> check_for_zeros = 1011 and 1-11 = "1011"
    -- Clock cycle +1 = "0-00" --> check_for_zeros = 1011 and 0-00 = "0000"
    -- In case of all zeros (Clock Cycle -1,+1) the OR reduce is '0', '1' in the other
    -- Finally we AND them together --> '0' in all cases
    -- ===============================
    -- Link 1 start is delayed by one clock cycle:
    -- ===============================
    -- Clock cycle -1 = "0-00" --> check_for_ones  = not (1011) or 0-00 = "0100"
    -- Clock cycle 0  = "1-01" --> check_for_ones  = not (1011) or 1-01 = "1101"
    -- Clock cycle +1 = "0-10" --> check_for_ones  = not (1011) or 0-10 = "0110"
    -- The NAND reduce is '1' in all the cases (no cases with all '1') 
    -- Clock cycle -1 = "0-00" --> check_for_zeros = 1011 and 0-00 = "0000"
    -- Clock cycle 0  = "1-11" --> check_for_zeros = 1011 and 1-01 = "1001"
    -- Clock cycle +1 = "0-00" --> check_for_zeros = 1011 and 0-10 = "0010"
    -- Only the first case the AND reduce is '0' (the one that hase all '0'), '1' elsewhere  
    -- Finally we AND them together --> we got a mismatch on CC 0 and +1 there fore a misaligment flag is assserted
    
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
