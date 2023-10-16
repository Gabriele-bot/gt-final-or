-- ipbus_initialized_dpram
--
-- Generic dual-port memory with ipbus access on one port.
-- Requires data file with one value per line in hexadecimal notation (no
-- '0x' though) for initialization.
--
-- Should lead to an inferred block RAM in Xilinx parts with modern tools
--
-- Note the wait state on ipbus access - full speed access is not possible
-- Can combine with peephole_ram access method for full speed access.
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
        COLUMNS       : integer                       := 2;
        ROWS          : integer                       := 2;
        DEFAULT_VALUE : std_logic_vector(31 downto 0) := (others => '0');
        ADDR_WIDTH    : positive;
        DATA_WIDTH    : positive                      := 32;
        STYLE         : string                        := "auto"
    );
    port(
        clk     : in  std_logic;
        rst     : in  std_logic;
        ipb_in  : in  ipb_wbus;
        ipb_out : out ipb_rbus
    );

end ipbus_file_init_menu_sprom;

architecture rtl of ipbus_file_init_menu_sprom is

    type rom_array is array (2 ** ADDR_WIDTH - 1 downto 0) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    impure function InitRamFromFile(file_name : in string) return rom_array is
        file F        : text open read_mode is file_name;
        variable L    : line;
        variable rom  : rom_array := (others => DEFAULT_VALUE(DATA_WIDTH - 1 downto 0));
    begin
        for i in 0 to ROWS-1 loop
            readline(F, L);
            for kk in 0 to COLUMNS-1 loop
                read(L, rom(i*COLUMNS + kk));
            end loop;
        end loop;
        return rom;
    end function;

    shared variable rom : rom_array                              := InitRamFromFile(DATA_FILE);
    signal sel          : integer range 0 to 2 ** ADDR_WIDTH - 1 := 0;
    signal ack          : std_logic;

    attribute ram_style : string;
    attribute ram_style of rom : variable is STYLE;

begin

    sel <= to_integer(unsigned(ipb_in.ipb_addr(ADDR_WIDTH - 1 downto 0)));

    process(clk)
    begin
        if rising_edge(clk) then

            ipb_out.ipb_rdata <= std_logic_vector(to_unsigned(0, 32 - DATA_WIDTH)) & rom(sel); -- Order of statements is important to infer read-first RAM!
            if ipb_in.ipb_strobe = '1' and ipb_in.ipb_write = '1' then
                rom(sel) := ipb_in.ipb_wdata(DATA_WIDTH - 1 downto 0);
            end if;
            ack               <= ipb_in.ipb_strobe and not ack;
        end if;
    end process;

    ipb_out.ipb_ack <= ack;
    ipb_out.ipb_err <= '0';

end rtl;
