
-- Description: demultiplexer of 360MHz data (from optical links) to 40MHz data
-- HEPHY 2015-06-04: 50bc suppressing for a) correct behaviour of FINOR, b) catching the correct data in SPYMEM3 for ROP analyze
-- HB 2015-02-05: cleaned up the code, removed port "del_a".
-- HEPHY 2014-19-12: cross clock domain has been changed and the adjusment over register has been disabled. This feature is tested on Dec.19 with new Caloslicetest 2015. The adjusment is done over butler script.
library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.VComponents.all;

use work.emp_data_types.all;

entity In_deser is
    port(
        clk360             : in std_logic;
        lhc_clk            : in std_logic;
        lane_data_in       : in lword;
        demux_data_o       : out std_logic_vector(9*64-1 downto 0)
    );
end In_deser;

architecture rtl of In_deser is

    signal temp : ldata(8 downto 0);
    signal data_in_suppress : lword;

begin

    -- TODO check the necessity of other signals
    data_in_suppress.data   <= (others => '0') when lane_data_in.valid = '0' else lane_data_in.data;
    data_in_suppress.valid  <= lane_data_in.valid;
    data_in_suppress.strobe <= lane_data_in.strobe;
    data_in_suppress.start  <= lane_data_in.start;
    
    
    temp(0) <= data_in_suppress;
    -- Pipeline for data (360MHz)
    pipeline_360MHz_p: process(clk360)
    begin
        if rising_edge(clk360) then
            --temp <= data_in_suppress & temp(7 downto 1);
            temp(8 downto 1) <= temp(7 downto 0);
        end if;
    end process;


    data_40mhz_p: process(lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            demux_data_o <= temp(0).data & temp(1).data & temp(2).data & temp(3).data & temp(4).data & temp(5).data & temp(6).data & temp(7).data & temp(8).data;
        end if;
    end process;


end architecture rtl;


