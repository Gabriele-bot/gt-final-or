library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;
use work.math_pkg.all;

entity CTRS_BX_nr_producer is
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
end entity CTRS_BX_nr_producer;

architecture RTL of CTRS_BX_nr_producer is

    type state_t is (idle, running);
    signal state      : state_t := idle;
    signal bx_nr_int  : unsigned(11 downto 0);
    signal p_ctr      : unsigned(3  downto 0);
    signal metadata   : std_logic_vector(3 downto 0);

begin

    metadata <= (start_of_orbit, start, last, valid);

    state_p :process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                p_ctr     <= to_unsigned(0,4);
                state <= idle;
            else
                case state is
                    when idle =>
                        if start_of_orbit = '1' and start = '1' then
                            p_ctr     <= to_unsigned(1,4);
                            state <= running;
                        end if;
                    when running =>
                        if metadata = "1101" or metadata =  "0101" then
                            p_ctr     <= to_unsigned(1,4);
                        elsif metadata =  "0011" then
                            p_ctr     <= (others => '0');
                        else
                            if p_ctr < 8 then
                                p_ctr     <= p_ctr + 1;
                            else
                                p_ctr     <= (others => '0');
                            end if;
                        end if;
                    when others =>
                        p_ctr     <= to_unsigned(0,4);
                        state <= idle;
                end case;
            end if;
        end if;
    end process;

    bctr_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                bx_nr_int <= to_unsigned(LHC_BUNCH_COUNT + 1,12); -- set to a safe value
            else
                if p_ctr >= 8 then
                    if bx_nr_int < LHC_BUNCH_COUNT-1 then
                        bx_nr_int     <= bx_nr_int + 1;
                    else
                        bx_nr_int <= (others => '0');
                    end if;
                end if;
                if metadata = "1101" then
                    bx_nr_int <= (others => '0');
                end if;
            end if;
        end if;
    end process bctr_p;

    bx_nr_360  <= std_logic_vector(to_unsigned(0,12)) when metadata = "1101" else std_logic_vector(bx_nr_int);

    process(clk40)
    begin
        if rising_edge(clk40) then
            bx_nr_40 <= std_logic_vector(bx_nr_int);
        end if;
    end process;


end architecture RTL;
