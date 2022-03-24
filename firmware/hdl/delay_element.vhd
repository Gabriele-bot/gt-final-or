
-- Description:
-- Delay element of a sigle bit signal.

-- Created by Gabriele Bortolato 21-03-2022

-- Version-history:

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.math_pkg.all;


entity delay_element is
    generic(
        MAX_DELAY : integer  := 63
    );
    port(
        clk     : in std_logic;
        rst     : in std_logic;
        data_i  : in std_logic;
        delay   : in std_logic_vector(log2c(MAX_DELAY)-1 downto 0);
        data_o  : out std_logic;
        valid_o : out std_logic
    );
end delay_element;

architecture RTL of delay_element is

    signal counter    : unsigned(log2c(MAX_DELAY)-1 downto 0)  := (others => '0');
    signal shift_reg  : std_logic_vector(MAX_DELAY-1 downto 0) := (others => '0');
    signal delay_prev : std_logic_vector(log2c(MAX_DELAY)-1 downto 0);

begin

    shift_reg_p : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then -- reset counter and shift register if reset is asserted
                shift_reg <= (others => '0');
                counter   <= (others => '0');
                valid_o   <= '0';
            elsif (delay_prev /= delay) then -- TODO review what heppens if delay changes
                counter    <= (others => '0');
                valid_o    <= '0';
                delay_prev <= delay;
            else
                delay_prev <= delay;
                shift_reg  <= shift_reg(MAX_DELAY-2 downto 0) & data_i; -- simple shift register
                if counter < unsigned(delay) then
                    counter <= counter + 1;
                    valid_o <= '0';
                elsif counter = unsigned(delay) then
                    data_o  <= shift_reg(to_integer(unsigned(delay))-1);
                    valid_o <= '1';
                else
                    counter <= (others => '0');
                    valid_o <= '0';
                end if;
            end if;
        end if;
    end process shift_reg_p;
    
    


end architecture RTL;

