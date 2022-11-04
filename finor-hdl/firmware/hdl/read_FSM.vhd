library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;
use work.math_pkg.all;


entity read_FSM is
    generic(
        RAM_DEPTH      : integer := 9;
        BEGIN_LUMI_BIT : integer := 18
    );
    port(
        clk            : in std_logic;
        rst            : in std_logic;
        load_flag      : in std_logic;
        orbit_nr       : in eoctr_t;
        lumi_sec_nr    : in std_logic_vector(31 downto 0);
        lumi_sec_load_mark : out std_logic_vector(31 downto 0);
        addr_o             : out std_logic_vector(log2c(RAM_DEPTH)-1 downto 0);
        addr_w_o           : out std_logic_vector(log2c(RAM_DEPTH)-1 downto 0);
        request_update     : out std_logic;
        ready_o            : out std_logic

    );
end entity read_FSM;

architecture RTL of read_FSM is

    type state_t is (idle, check, load, done);
    signal state : state_t := idle;

    signal addr, addr_w : unsigned(log2c(RAM_DEPTH)-1 downto 0);
    signal ready : std_logic;

begin

    process (clk)
    begin
        if rising_edge(clk) then
            case state is
                when idle   =>
                    addr  <= (others => '0');
                    request_update <= '0';
                    ready          <= '1';
                    if load_flag = '1' then
                        state <= check;
                    end if;
                when check  =>
                    if unsigned(orbit_nr(BEGIN_LUMI_BIT - 1 downto 0)) <= to_unsigned(2**BEGIN_LUMI_BIT - 2, BEGIN_LUMI_BIT) then
                        addr  <= (others => '0');
                        request_update <= '0';
                        ready          <= '0';
                        state <= load;
                    else
                        addr  <= (others => '0');
                        request_update <= '0';
                        ready          <= '1';
                        state <= check;
                    end if;
                when load    =>
                    if addr >= RAM_DEPTH-1 then
                        addr  <= (others => '0');
                        request_update <= '0';
                        ready          <= '0';
                        state <= done;
                    else
                        addr  <= addr + 1;
                        request_update <= '0';
                        ready          <= '0';
                        state <= load;
                    end if;
                when done   =>
                    lumi_sec_load_mark <= std_logic_vector(unsigned(lumi_sec_nr) + 1);
                    request_update <= '1';
                    ready          <= '1';
                    state          <= idle;
                when others =>
                    request_update <= '0';
                    ready          <= '0';
                    state          <= idle;

            end case;
        end if;
    end process;

    process (clk)
    begin
        if rising_edge(clk) then
            addr_w <= addr;
        end if;
    end process;


    addr_o   <= std_logic_vector(addr);
    addr_w_o <= std_logic_vector(addr_w);
    ready_o  <= ready;




end architecture RTL;
