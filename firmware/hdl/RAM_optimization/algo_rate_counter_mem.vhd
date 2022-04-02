library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity algo_rate_counter_mem is
    generic(
        COUNTER_WIDTH : integer := 32
    );
    port(
        sys_clk          : in     std_logic;
        lhc_clk          : in     std_logic;
        clk_x9           : in     std_logic;
        rst_x9           : in     std_logic;
        sres_counter     : in     std_logic;
        store_cnt_value  : in     std_logic;
        algo_i           : in     std_logic;
        counter_i        : in     std_logic_vector(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
        counter_o        : out    std_logic_vector(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0')
    );
end entity algo_rate_counter_mem;

architecture RTL of algo_rate_counter_mem is

    constant END_CNT     : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '1');

    signal counter_o_s   : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal counter_i_s   : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '0');
    signal limit         : std_logic := '0';

begin


    counter_i_s <= unsigned(counter_i);

    counter_p: process (clk_x9)
    begin
        if rising_edge(clk_x9) then
            if rst_x9 = '1' then
                counter_o_s <= (others => '0');
            elsif sres_counter = '1' or store_cnt_value = '1' then
                if (limit = '0' and algo_i = '1') then
                    counter_o_s <= to_unsigned(1, COUNTER_WIDTH); -- this (re)sets the counter value to 1 if there occurs a trigger just in the 'store_cnt_value' clk cycle
                else
                    counter_o_s <= (others => '0'); -- clear counter with synchr. reset and store_cnt_value (which is begin of lumi section)
                end if;
            elsif (limit = '0' and algo_i = '1') then
                counter_o_s <= counter_i_s + 1;
            else
                counter_o_s <= counter_i_s;
            end if;
        end if;
    end process counter_p;

    compare_p: process (counter_i_s)
    begin
        if (counter_i_s = END_CNT) then
            limit <= '1';
        else
            limit <= '0';
        end if;
    end process compare_p;

    counter_o   <= std_logic_vector(counter_o_s);
end architecture RTL;
