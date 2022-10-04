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

package ipbus_decode_Output_SLR is

  constant IPBUS_SEL_WIDTH: positive := 2;
  subtype ipbus_sel_t is std_logic_vector(IPBUS_SEL_WIDTH - 1 downto 0);
  function ipbus_sel_Output_SLR(addr : in std_logic_vector(31 downto 0)) return ipbus_sel_t;

-- START automatically  generated VHDL the Fri Sep 16 14:35:13 2022 
  constant N_SLV_CNT_RATE_FINOR: integer := 0;
  constant N_SLV_CNT_RATE_FINOR_PDT: integer := 1;
  constant N_SLV_CSR: integer := 2;
  constant N_SLAVES: integer := 3;
-- END automatically generated VHDL

    
end ipbus_decode_Output_SLR;

package body ipbus_decode_Output_SLR is

  function ipbus_sel_Output_SLR(addr : in std_logic_vector(31 downto 0)) return ipbus_sel_t is
    variable sel: ipbus_sel_t;
  begin

-- START automatically  generated VHDL the Fri Sep 16 14:35:13 2022 
    if    std_match(addr, "--------------------------00----") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_CNT_RATE_FINOR, IPBUS_SEL_WIDTH)); -- cnt_rate_finor / base 0x00000000 / mask 0x00000030
    elsif std_match(addr, "--------------------------01----") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_CNT_RATE_FINOR_PDT, IPBUS_SEL_WIDTH)); -- cnt_rate_finor_pdt / base 0x00000010 / mask 0x00000030
    elsif std_match(addr, "--------------------------10----") then
      sel := ipbus_sel_t(to_unsigned(N_SLV_CSR, IPBUS_SEL_WIDTH)); -- CSR / base 0x00000020 / mask 0x00000030
-- END automatically generated VHDL

    else
        sel := ipbus_sel_t(to_unsigned(N_SLAVES, IPBUS_SEL_WIDTH));
    end if;

    return sel;

  end function ipbus_sel_Output_SLR;

end ipbus_decode_Output_SLR;

