library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;
use work.math_pkg.all;

entity write_FSM is
    generic(
        RAM_DEPTH : integer := 9
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        write_flag : in  std_logic;
        addr_o     : out std_logic_vector(log2c(RAM_DEPTH) - 1 downto 0);
        addr_w_o   : out std_logic_vector(log2c(RAM_DEPTH) - 1 downto 0);
        we_o       : out std_logic
    );
end entity write_FSM;

architecture RTL of write_FSM is

    type state_t is (idle, check, increment, done);
    signal state : state_t := idle;

    signal addr, addr_w : unsigned(log2c(RAM_DEPTH) - 1 downto 0);
    signal we           : std_logic;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= idle;
                addr  <= (others => '0');
                we    <= '0';
            else
                case state is
                    when idle =>
                        addr <= (others => '0');
                        if write_flag = '1' then
                            addr  <= (others => '0');
                            we    <= '1';
                            state <= increment;
                        else
                            addr  <= (others => '0');
                            we    <= '0';
                            state <= idle;
                        end if;
                    when increment =>
                        if addr >= RAM_DEPTH - 1 then
                            addr  <= (others => '0');
                            we    <= '0';
                            state <= done;
                        else
                            addr  <= addr + 1;
                            we    <= '1';
                            state <= increment;
                        end if;
                    when done =>
                        addr  <= (others => '0');
                        we    <= '0';
                        state <= idle;
                    when others =>
                        state <= idle;
                        addr  <= (others => '0');
                        we    <= '0';
                end case;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            addr_w <= addr;
        end if;
    end process;

    addr_o   <= std_logic_vector(addr);
    addr_w_o <= std_logic_vector(addr_w);
    we_o     <= we;

end architecture RTL;
