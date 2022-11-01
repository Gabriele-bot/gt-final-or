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

package ipbus_decode_m_module is

  constant IPBUS_SEL_WIDTH: positive := 4;
  subtype ipbus_sel_t is std_logic_vector(IPBUS_SEL_WIDTH - 1 downto 0);
  function ipbus_sel_m_module(addr : in std_logic_vector(31 downto 0)) return ipbus_sel_t;

-- START automatically generated VHDL (Mon May 16 11:43:23 2022)
  constant N_SLV_PRESCALE_FACTOR: integer := 0;
  constant N_SLV_PRESCALE_FACTOR_PRVW: integer := 1;
  constant N_SLV_CNT_RATE_BEFORE_PRSC: integer := 2;
  constant N_SLV_CNT_RATE_AFTER_PRSC: integer := 3;
  constant N_SLV_CNT_RATE_AFTER_PRSC_PRVW: integer := 4;
  constant N_SLV_CNT_RATE_PDT: integer := 5;
  constant N_SLV_CSR: integer := 6;
  constant N_SLV_TRGG_MASK: integer := 7;
  constant N_SLAVES: integer := 8;
-- END automatically generated VHDL

    
end ipbus_decode_m_module;

package body ipbus_decode_m_module is

  function ipbus_sel_m_module(addr : in std_logic_vector(31 downto 0)) return ipbus_sel_t is
    variable sel: ipbus_sel_t;
  begin

-- START automatically generated VHDL (Mon May 16 11:43:23 2022)
    if    std_match(addr, "-----------------000------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_PRESCALE_FACTOR, IPBUS_SEL_WIDTH)); -- prescale_factor / base 0x00000000 / mask 0x00007000
    elsif std_match(addr, "-----------------001------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_PRESCALE_FACTOR_PRVW, IPBUS_SEL_WIDTH)); -- prescale_factor_prvw / base 0x00001000 / mask 0x00007000
    elsif std_match(addr, "-----------------010------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_CNT_RATE_BEFORE_PRSC, IPBUS_SEL_WIDTH)); -- cnt_rate_before_prsc / base 0x00002000 / mask 0x00007000
    elsif std_match(addr, "-----------------011------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_CNT_RATE_AFTER_PRSC, IPBUS_SEL_WIDTH)); -- cnt_rate_after_prsc / base 0x00003000 / mask 0x00007000
    elsif std_match(addr, "-----------------100------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_CNT_RATE_AFTER_PRSC_PRVW, IPBUS_SEL_WIDTH)); -- cnt_rate_after_prsc_prvw / base 0x00004000 / mask 0x00007000
    elsif std_match(addr, "-----------------101------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_CNT_RATE_PDT, IPBUS_SEL_WIDTH)); -- cnt_rate_pdt / base 0x00005000 / mask 0x00007000
    elsif std_match(addr, "-----------------110------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_CSR, IPBUS_SEL_WIDTH)); -- CSR / base 0x00006000 / mask 0x00007000
    elsif std_match(addr, "-----------------111------------") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_TRGG_MASK, IPBUS_SEL_WIDTH)); -- trgg_mask / base 0x00007000 / mask 0x00007000
-- END automatically generated VHDL

    else
        sel := ipbus_sel_t(to_unsigned(N_SLAVES, IPBUS_SEL_WIDTH));
    end if;

    return sel;

  end function ipbus_sel_m_module;

end ipbus_decode_m_module;
