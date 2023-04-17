library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.emp_data_types.all;
use work.emp_project_decl.all;
use work.ipbus_decode_SLR_FinOR_unit.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity BX_nr_producer is
    port(
        clk360         : in std_logic;
        rst360         : in std_logic;
        clk40          : in std_logic;
        rst40          : in std_logic;
        valid          : in std_logic;
        last           : in std_logic;
        start          : in std_logic;
        start_of_orbit : in std_logic;
        bx_nr_40       : out bctr_t;
        bx_nr_360      : out bctr_t
    );
end entity BX_nr_producer;

architecture RTL of BX_nr_producer is

    signal bx_nr_int : unsigned(11 downto 0);
    signal p_ctr     : unsigned(3  downto 0);
    signal metadata  : std_logic_vector(3 downto 0);

begin

    metadata <= (start_of_orbit, start, last, valid);

    pctr_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                p_ctr <=  (others => '0');
            else
                case metadata is
                    when "1101" =>
                        p_ctr     <= to_unsigned(1,4);
                    when "0101" =>
                        p_ctr     <= to_unsigned(1,4);
                    when "0011" =>
                        p_ctr     <= (others => '0');
                    when others =>
                        if p_ctr < 8 then
                            p_ctr     <= p_ctr + 1;
                        else
                            p_ctr     <= (others => '0');
                        end if;
                end case;
            end if;
        end if;
    end process pctr_p;

    bctr_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                bx_nr_int <= to_unsigned(255,12);
            else
                if p_ctr >= 8 then
                    if bx_nr_int < LHC_BUNCH_COUNT-1 then
                        bx_nr_int     <= bx_nr_int + 1;
                    else
                        bx_nr_int <= (others => '0');
                    end if;
                end if;
                if start_of_orbit = '1' then
                    bx_nr_int <= (others => '0');
                end if;
            end if;
        end if;
    end process bctr_p;

    bx_nr_360  <= std_logic_vector(bx_nr_int);

    process(clk40)
    begin
        if rising_edge(clk40) then
            bx_nr_40 <= std_logic_vector(bx_nr_int);
        end if;
    end process;


end architecture RTL;