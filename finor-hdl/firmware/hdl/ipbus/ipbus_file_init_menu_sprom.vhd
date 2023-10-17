-- ipbus_initialized_dpram
--
-- Generic ROM with ipbus access.
-- Requires data file with one value per line in binary notation (no
-- '0x' though) for initialization.
--
-- Should lead to an inferred block RAM in Xilinx parts with modern tools
--
-- Dave Newbold, July 2013
-- Gabriele Bortolato, August 2022 
-- Module based on Dinyar Rabady code

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.ipbus.all;

use STD.TEXTIO.all;

entity ipbus_file_init_menu_sprom is
    generic(
        DATA_FILE     : string;
        FILE_LENGTH   : integer := 2;
        ADDR_WIDTH    : integer := 2;
        DEFAULT_VALUE : std_logic_vector(31 downto 0) := (others => '0');
        DATA_WIDTH    : positive                      := 32;
        STYLE         : string                        := "auto"
    );
    port(
        clk     : in  std_logic;
        ipb_in  : in  ipb_wbus;
        ipb_out : out ipb_rbus
    );

end ipbus_file_init_menu_sprom;

architecture rtl of ipbus_file_init_menu_sprom is

    type rom_array is array (2 ** ADDR_WIDTH - 1 downto 0) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    impure function InitRamFromFile(file_name : in string) return rom_array is
        file F       : text open read_mode is file_name;
        variable L   : line;
        variable rom : rom_array := (others => DEFAULT_VALUE(DATA_WIDTH - 1 downto 0));
    begin
        for i in 0 to FILE_LENGTH - 1 loop
            readline(F, L);
            read(L, rom(i));
        end loop;
        return rom;
    end function;

    signal rom : rom_array                              := InitRamFromFile(DATA_FILE);
    signal sel : integer range 0 to 2 ** ADDR_WIDTH - 1 := 0;
    signal ack : std_logic;

    attribute ram_style : string;
    attribute ram_style of rom : signal is STYLE;

begin
    
    assert FILE_LENGTH < 2**ADDR_WIDTH
    report "FILE LENGTH (" & integer'image(FILE_LENGTH) & ") is greater than the address space (" & integer'image(2**ADDR_WIDTH) &")"
    severity FAILURE;

    sel <= to_integer(unsigned(ipb_in.ipb_addr(ADDR_WIDTH - 1 downto 0)));

    process(clk)
    begin
        if rising_edge(clk) then
            ipb_out.ipb_rdata <= std_logic_vector(to_unsigned(0, 32 - DATA_WIDTH)) & rom(sel);
            ack               <= ipb_in.ipb_strobe and not ack;
        end if;
    end process;

    ipb_out.ipb_ack <= ack;
    ipb_out.ipb_err <= '0';

end rtl;
