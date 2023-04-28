-- Based on the code that can be found out here https://vhdlwhiz.com/ring-buffer-fifo/ 
-- 1 is the minimum dalay that can be set, note that the output is delayed further by 1 clock cycle due to the last process (register)
-- First values could not be forwarded to the output if the delay value comes late than the actual input

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pkg.all;

entity delay_element_ringbuffer is
    generic (
        DATA_WIDTH         : integer := 64;
        MAX_DELAY          : integer := 63;
        RESET_WITH_NEW_DEL : boolean := TRUE
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        data_i    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        data_o    : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        delay_lkd : in  std_logic;
        delay     : in  std_logic_vector(log2c(MAX_DELAY)-1 downto 0) := (others => '0')
    );
end entity delay_element_ringbuffer;

architecture RTL of delay_element_ringbuffer is
    
    constant MAX_VAL_UNISGNED  : unsigned(log2c(MAX_DELAY)-1 downto 0) := (others => '1');

    type ram_type is array (0 to 2**log2c(MAX_DELAY) - 1) of std_logic_vector(data_i'range);
    signal ram : ram_type;

    subtype index_type is integer range ram_type'range;
    signal head : index_type;
    signal tail : index_type;
    
    signal head_unsigned : unsigned(log2c(MAX_DELAY)-1 downto 0);
    signal tail_unsigned : unsigned(log2c(MAX_DELAY)-1 downto 0);

    signal curr_delay : unsigned(log2c(MAX_DELAY)-1 downto 0) := (others => '0');
    signal delay_reg  : std_logic_vector(log2c(MAX_DELAY)-1 downto 0) := (others => '0');

    signal rst_loc : std_logic;

    -- Increment and wrap
    procedure incr(signal index : inout index_type) is
    begin
        if index = index_type'high then
            index <= index_type'low;
        else
            index <= index + 1;
        end if;
    end procedure;

begin

    check_dealy_var : process (clk)
    begin
        if rising_edge(clk) then
            delay_reg <= delay;
        end if;
    end process;

    gen_reset_g : if RESET_WITH_NEW_DEL generate
        process (rst, delay_reg, delay)
        begin
            if rst = '1' or ((delay_reg /= delay)) then
                rst_loc <= '1';
            else
                rst_loc <= '0';
            end if;
        end process;
    else generate
        rst_loc <= rst;
    end generate;


    PROC_HEAD : process(clk)
    begin
        if rising_edge(clk) then
            if (rst_loc = '1')  then
                head <= 0;
            else
                incr(head);
            end if;
        end if;
    end process;
    
    head_unsigned  <= to_unsigned(head,log2c(MAX_DELAY));

    -- Update the tail pointer on read and pulse valid
    PROC_TAIL : process(rst_loc, head_unsigned, delay, delay_lkd)
    begin
        --if rising_edge(clk) then
            if (rst_loc = '1') then
                tail_unsigned <= (others => '0');
            else
                if delay_lkd = '1' then
                    tail_unsigned  <= head_unsigned - unsigned(delay);
                else
                    tail_unsigned <= (others => '0');
                end if;
            end if;
        --end if;
    end process;
    
    tail  <= to_integer(tail_unsigned);


    -- Write to and read from the RAM
    PROC_RAM : process(clk)
    begin
        if rising_edge(clk) then
            ram(head) <= data_i;
            if delay_lkd = '1' then
                if unsigned(delay) = 0 then
                    data_o <= data_i;
                else 
                    data_o <= ram(tail);
                end if;
            else
                data_o <= (others => '0');
            end if;
        end if;
    end process;


end architecture RTL;
