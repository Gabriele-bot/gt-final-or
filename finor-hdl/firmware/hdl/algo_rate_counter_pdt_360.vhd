library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.P2GT_finor_pkg.all;

entity algo_rate_counter_pdt_360 is
    generic(
        COUNTER_WIDTH : integer := 32
    );
    port(
        clk              : in     std_logic;
        sres_counter     : in     std_logic;
        store_cnt_value  : in     std_logic;
        algo_del_i       : in     std_logic;
        frame_ctr        : in     std_logic_vector(3 downto 0);
        l1a              : in     std_logic;
        counter_o        : out    rate_counter_array(8 downto 0) -- init value (for simulation)
    );
end algo_rate_counter_pdt_360;

architecture rtl of algo_rate_counter_pdt_360 is

    type counter_arr is array (8 downto 0) of unsigned(COUNTER_WIDTH-1 downto 0);

    constant counter_end : unsigned(COUNTER_WIDTH-1 DOWNTO 0) := (others => '1'); -- counter stops at this value
    signal counters      : counter_arr := (others => (others => '0'));
    signal counters_int  : counter_arr := (others => (others => '0'));
    signal limits        : std_logic_vector(8 downto 0) := (others => '0');

    signal frame_ctr_integer    : integer range 0 to 8;

    signal store_cnt_val_del : std_logic;

begin

    frame_ctr_integer <= to_integer(unsigned(frame_ctr));

    counter_p: process (clk)
    begin
        if rising_edge(clk) then
            if sres_counter = '1' or store_cnt_value = '1' then
                if (limits(frame_ctr_integer) = '0' and algo_del_i = '1' and l1a = '1') then
                    counters(frame_ctr_integer) <= to_unsigned(1, COUNTER_WIDTH); -- this (re)sets the counter value to 1 if there occurs a trigger just in the 'store_cnt_value' clk cycle
                else
                    counters(frame_ctr_integer) <= (others => '0'); -- clear counter with synchr. reset and store_cnt_value (which is begin of lumi section)
                end if;
            elsif limits(frame_ctr_integer) = '1' then
                counters(frame_ctr_integer) <= counter_end;
            elsif (limits(frame_ctr_integer) = '0' and algo_del_i = '1' and l1a = '1') then
                counters(frame_ctr_integer) <= counters(frame_ctr_integer) + 1;
            end if;
        end if;
    end process counter_p;

    compare_gen_l: for i in 0 to 8 generate
        compare_p: process (counters(i))
        begin
            if (counters(i) = counter_end) then
                limits(i) <= '1';
            else
                limits(i) <= '0';
            end if;
        end process compare_p;
    end generate;

    store_int_p: process (clk)
    begin
        if rising_edge(clk) then
            if store_cnt_value = '1' then
                counters_int(frame_ctr_integer) <= counters(frame_ctr_integer); -- "store" counter value internally for read access with store_cnt_value (which is begin of lumi section)
            end if;
        end if;
    end process store_int_p;

    out_gen_l: for i in 0 to 8 generate
        out_p: process (clk)
        begin
            if rising_edge(clk) then
                store_cnt_val_del <= store_cnt_value;
                if store_cnt_val_del = '1' and store_cnt_value = '0' then --falling edge
                    counter_o(0) <= std_logic_vector(counters_int(0));
                    counter_o(1) <= std_logic_vector(counters_int(1));
                    counter_o(2) <= std_logic_vector(counters_int(2));
                    counter_o(3) <= std_logic_vector(counters_int(3));
                    counter_o(4) <= std_logic_vector(counters_int(4));
                    counter_o(5) <= std_logic_vector(counters_int(5));
                    counter_o(6) <= std_logic_vector(counters_int(6));
                    counter_o(7) <= std_logic_vector(counters_int(7));
                    counter_o(8) <= std_logic_vector(counters_int(8));
                end if;
            end if;
        end process;
    end generate;

end architecture rtl;

-- TODO ask which clk to use