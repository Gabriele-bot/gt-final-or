
-- GB 29-07-2022: new version, deserializer synchronized with link_valid.
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

    signal data_deserialized : std_logic_vector(9*64 - 1 downto 0);
    signal data_deserialized_temp : std_logic_vector(8*64 - 1 downto 0);
    
    signal frame_cntr : integer range 0 to 8;

begin


    frame_counter_p : process (clk360)
        --variable frame_cntr : integer range 0 to 8;
    begin
        if rising_edge(clk360) then -- rising clock edge
            if lane_data_in.valid = '0' then
                frame_cntr <= 0;
                data_deserialized <= (others => '0');
            elsif frame_cntr < 8 then
                frame_cntr <= frame_cntr + 1;
                data_deserialized_temp(frame_cntr * 64 + 63 downto frame_cntr * 64) <= lane_data_in.data;
            else
                frame_cntr <= 0;
                data_deserialized(frame_cntr * 64 + 63 downto frame_cntr * 64) <= lane_data_in.data;
                data_deserialized((frame_cntr-1) * 64 + 63 downto 0) <= data_deserialized_temp((frame_cntr-1) * 64 + 63 downto 0);
            end if;

        end if;
    end process frame_counter_p;



    data_40mhz_p: process(lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            demux_data_o <= data_deserialized;
        end if;
    end process;


end architecture rtl;