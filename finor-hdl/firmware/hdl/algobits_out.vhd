library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity algobits_out is
    port(
        clk360               : in  std_logic;
        rst360               : in  std_logic;
        clk40                : in  std_logic;
        rst40                : in  std_logic;
        ctrs                 : in  ttc_stuff_t;
        algos_in             : in  std_logic_vector(N_SLR_ALGOS - 1 downto 0);
        algos_after_bxmask   : in  std_logic_vector(N_SLR_ALGOS - 1 downto 0);
        algos_after_prscl    : in  std_logic_vector(N_SLR_ALGOS - 1 downto 0);
        algos_valid          : in  std_logic;
        q_algos              : out lword;
        q_algos_after_bxmask : out lword;
        q_algos_after_prscl  : out lword
    );
end entity algobits_out;

architecture RTL of algobits_out is

    signal ctrs_internal : ttc_stuff_t;

    signal algos_in_padded           : std_logic_vector(LWORD_WIDTH * 9 - 1 downto 0);
    signal algos_after_bxmask_padded : std_logic_vector(LWORD_WIDTH * 9 - 1 downto 0);
    signal algos_after_prscl_padded  : std_logic_vector(LWORD_WIDTH * 9 - 1 downto 0);

begin

    -- TODO put condition that N algos shuld not be greater than 576 here
    padd_g : if N_SLR_ALGOS >= (LWORD_WIDTH * 9) generate
        algos_in_padded           <= algos_in(LWORD_WIDTH * 9 - 1 downto 0);
        algos_after_bxmask_padded <= algos_after_bxmask(LWORD_WIDTH * 9 - 1 downto 0);
        algos_after_prscl_padded  <= algos_after_prscl(LWORD_WIDTH * 9 - 1 downto 0);
    else generate
        algos_in_padded(N_SLR_ALGOS - 1 downto 0)                         <= algos_in;
        algos_in_padded(LWORD_WIDTH * 9 - 1 downto N_SLR_ALGOS)           <= (others => '0');
        algos_after_bxmask_padded(N_SLR_ALGOS - 1 downto 0)               <= algos_after_bxmask;
        algos_after_bxmask_padded(LWORD_WIDTH * 9 - 1 downto N_SLR_ALGOS) <= (others => '0');
        algos_after_prscl_padded(N_SLR_ALGOS - 1 downto 0)                <= algos_after_prscl;
        algos_after_prscl_padded(LWORD_WIDTH * 9 - 1 downto N_SLR_ALGOS)  <= (others => '0');
    end generate;

    sync_40_p : process(clk40)
    begin
        if rising_edge(clk40) then
            ctrs_internal <= ctrs;
        end if;
    end process;

    mux_algos_before_prscl_out : entity work.mux
        port map(
            clk360      => clk360,
            rst360      => rst360,
            clk40       => clk40,
            rst40       => rst40,
            bctr        => ctrs_internal.bctr,
            input_40MHz => algos_in_padded,
            valid_in    => algos_valid,
            output_data => q_algos
        );

    mux_algos_after_prscl_out : entity work.mux
        port map(
            clk360      => clk360,
            rst360      => rst360,
            clk40       => clk40,
            rst40       => rst40,
            bctr        => ctrs_internal.bctr,
            input_40MHz => algos_after_bxmask_padded,
            valid_in    => algos_valid,
            output_data => q_algos_after_bxmask
        );

    mux_algos_after_prscl_prvw_out : entity work.mux
        port map(
            clk360      => clk360,
            rst360      => rst360,
            clk40       => clk40,
            rst40       => rst40,
            bctr        => ctrs_internal.bctr,
            input_40MHz => algos_after_prscl_padded,
            valid_in    => algos_valid,
            output_data => q_algos_after_prscl
        );

end architecture RTL;
