-- Address decode logic for ipbus fabric
-- 
-- This file has been AUTOGENERATED from the address table - do not hand edit
-- 
-- We assume the synthesis tool is clever enough to recognise exclusive conditions
-- in the if statement.
-- 
-- Dave Newbold, February 2011

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

package ipbus_decode_dpram_4096x576 is

  constant IPBUS_SEL_WIDTH: positive := 5;
  subtype ipbus_sel_t is std_logic_vector(IPBUS_SEL_WIDTH - 1 downto 0);
  function ipbus_sel_dpram_4096x576(addr : in std_logic_vector(31 downto 0)) return ipbus_sel_t;

-- START automatically generated VHDL (Wed Aug 10 15:35:09 2022)
  constant N_SLV_DATA_0_31: integer := 0;
  constant N_SLV_DATA_32_63: integer := 1;
  constant N_SLV_DATA_64_95: integer := 2;
  constant N_SLV_DATA_96_127: integer := 3;
  constant N_SLV_DATA_128_159: integer := 4;
  constant N_SLV_DATA_160_191: integer := 5;
  constant N_SLV_DATA_192_223: integer := 6;
  constant N_SLV_DATA_224_255: integer := 7;
  constant N_SLV_DATA_256_287: integer := 8;
  constant N_SLV_DATA_288_319: integer := 9;
  constant N_SLV_DATA_320_351: integer := 10;
  constant N_SLV_DATA_352_383: integer := 11;
  constant N_SLV_DATA_384_415: integer := 12;
  constant N_SLV_DATA_416_447: integer := 13;
  constant N_SLV_DATA_448_479: integer := 14;
  constant N_SLV_DATA_480_511: integer := 15;
  constant N_SLV_DATA_512_543: integer := 16;
  constant N_SLV_DATA_544_575: integer := 17;
  constant N_SLAVES: integer := 18;
-- END automatically generated VHDL

    
end ipbus_decode_dpram_4096x576;

package body ipbus_decode_dpram_4096x576 is

  function ipbus_sel_dpram_4096x576(addr : in std_logic_vector(31 downto 0)) return ipbus_sel_t is
    variable sel: ipbus_sel_t;
  begin

-- START automatically generated VHDL (Wed Aug 10 15:35:09 2022)
    if    std_match(addr, "---------------00000------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_0_31, IPBUS_SEL_WIDTH)); -- data_0_31 / base 0x00000000 / mask 0x0001f000
    elsif std_match(addr, "---------------00001------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_32_63, IPBUS_SEL_WIDTH)); -- data_32_63 / base 0x00001000 / mask 0x0001f000
    elsif std_match(addr, "---------------00010------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_64_95, IPBUS_SEL_WIDTH)); -- data_64_95 / base 0x00002000 / mask 0x0001f000
    elsif std_match(addr, "---------------00011------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_96_127, IPBUS_SEL_WIDTH)); -- data_96_127 / base 0x00003000 / mask 0x0001f000
    elsif std_match(addr, "---------------00100------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_128_159, IPBUS_SEL_WIDTH)); -- data_128_159 / base 0x00004000 / mask 0x0001f000
    elsif std_match(addr, "---------------00101------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_160_191, IPBUS_SEL_WIDTH)); -- data_160_191 / base 0x00005000 / mask 0x0001f000
    elsif std_match(addr, "---------------00110------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_192_223, IPBUS_SEL_WIDTH)); -- data_192_223 / base 0x00006000 / mask 0x0001f000
    elsif std_match(addr, "---------------00111------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_224_255, IPBUS_SEL_WIDTH)); -- data_224_255 / base 0x00007000 / mask 0x0001f000
    elsif std_match(addr, "---------------01000------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_256_287, IPBUS_SEL_WIDTH)); -- data_256_287 / base 0x00008000 / mask 0x0001f000
    elsif std_match(addr, "---------------01001------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_288_319, IPBUS_SEL_WIDTH)); -- data_288_319 / base 0x00009000 / mask 0x0001f000
    elsif std_match(addr, "---------------01010------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_320_351, IPBUS_SEL_WIDTH)); -- data_320_351 / base 0x0000a000 / mask 0x0001f000
    elsif std_match(addr, "---------------01011------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_352_383, IPBUS_SEL_WIDTH)); -- data_352_383 / base 0x0000b000 / mask 0x0001f000
    elsif std_match(addr, "---------------01100------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_384_415, IPBUS_SEL_WIDTH)); -- data_384_415 / base 0x0000c000 / mask 0x0001f000
    elsif std_match(addr, "---------------01101------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_416_447, IPBUS_SEL_WIDTH)); -- data_416_447 / base 0x0000d000 / mask 0x0001f000
    elsif std_match(addr, "---------------01110------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_448_479, IPBUS_SEL_WIDTH)); -- data_448_479 / base 0x0000e000 / mask 0x0001f000
    elsif std_match(addr, "---------------01111------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_480_511, IPBUS_SEL_WIDTH)); -- data_480_511 / base 0x0000f000 / mask 0x0001f000
    elsif std_match(addr, "---------------10000------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_512_543, IPBUS_SEL_WIDTH)); -- data_512_543 / base 0x00010000 / mask 0x0001f000
    elsif std_match(addr, "---------------10001------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_DATA_544_575, IPBUS_SEL_WIDTH)); -- data_544_575 / base 0x00011000 / mask 0x0001f000
-- END automatically generated VHDL

    else
        sel := ipbus_sel_t(to_unsigned(N_SLAVES, IPBUS_SEL_WIDTH));
    end if;

    return sel;

  end function ipbus_sel_dpram_4096x576;

end ipbus_decode_dpram_4096x576;

