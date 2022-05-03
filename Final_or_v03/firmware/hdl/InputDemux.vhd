
-- Description: demultiplexer of 360MHz data (from optical links) to 40MHz data

-- Created by Gabriele Bortolato 01-04-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware)


-- Version-history:
-- GB : make some modifications;

-- Resources utilization
-- |       | Synth |  Impl |
-- |-------|-------|-------|
-- | LUT   |  30   |  30   |
-- | FF    |  1152 |  1152 |
----------------------------



library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.VComponents.all;

use work.emp_data_types.all;

entity InputDemux is
    port(
        clk360             : in std_logic;
        lhc_clk            : in std_logic;
        lane_data_in       : in lword;
        demux_data_o       : out std_logic_vector(9*64-1 downto 0)
    );
end InputDemux;

architecture rtl of InputDemux is

    signal temp : ldata(8 downto 0);
    signal data_in_suppress : lword;

begin

    -- TODO check the necessity of other signals
    data_in_suppress.data   <= (others => '0') when lane_data_in.valid = '0' else lane_data_in.data;
    data_in_suppress.valid  <= lane_data_in.valid;
    data_in_suppress.strobe <= lane_data_in.strobe;
    data_in_suppress.start  <= lane_data_in.start;

    -- Pipeline for data (360MHz)
    pipeline_360MHz_p: process(clk360)
    begin
        if rising_edge(clk360) then
            temp <= data_in_suppress & temp(8 downto 1);
        end if;
    end process;

    
    data_40mhz_p: process(lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            demux_data_o <= data_in_suppress.data & temp(0).data & temp(1).data & temp(2).data & temp(3).data & temp(4).data & temp(5).data & temp(6).data & temp(7).data;
            --demux_data_o <= (temp(0).data, temp(1).data, temp(2).data, temp(3).data, temp(4).data, temp(5).data, temp(6).data, temp(7).data, temp(8).data);
        end if;
    end process;

end architecture rtl;


