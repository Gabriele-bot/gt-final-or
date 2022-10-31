-- GB 29-07-2022: new version, deserializer synchronized with link_valid.
library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.VComponents.all;

use work.emp_data_types.all;
use work.emp_ttc_decl.all;
entity In_deser is
    port(
        clk360             : in std_logic;
        lhc_clk            : in std_logic;
        lhc_rst            : in std_logic;
        lane_data_in       : in lword;
        demux_data_o       : out std_logic_vector(9*64-1 downto 0)
    );
end In_deser;

architecture rtl of In_deser is

    signal data_deserialized      : std_logic_vector(9*64 - 1 downto 0);
    signal data_deserialized_temp : std_logic_vector(8*64 - 1 downto 0);

    signal data_in_valid_del_arr  : std_logic_vector(9 downto 0);

    signal frame_cntr,  frame_cntr_temp: integer range 0 to 8;

begin

    data_in_valid_del_arr(0) <= lane_data_in.valid;
    del_valid_p : process (clk360)
    begin
        if rising_edge(clk360) then -- rising clock edge
            data_in_valid_del_arr(9 downto 1) <=  data_in_valid_del_arr(8 downto 0);
        end if;
    end process del_valid_p;


    frame_counter_p : process (clk360)
    begin
        if rising_edge(clk360) then -- rising clock edge
            if lane_data_in.valid = '0' then
                frame_cntr <= 0;
            elsif frame_cntr < 8 then
                frame_cntr <= frame_cntr + 1;
                data_deserialized_temp(frame_cntr * 64 + 63 downto frame_cntr * 64) <= lane_data_in.data;
            else
                frame_cntr <= 0;
            end if;
        end if;
    end process frame_counter_p;
    
    frame_counter_temp_p : process (clk360)
    begin
        if rising_edge(clk360) then
            if data_in_valid_del_arr(9) = '0' then
                    frame_cntr_temp <= 0;
            elsif frame_cntr_temp < 8 then
                    frame_cntr_temp <= frame_cntr_temp + 1;
            else
                    frame_cntr_temp <= 0;
            end if;
        end if;
    end process frame_counter_temp_p;

    load_data_p : process (clk360)
    begin
        if rising_edge(clk360) then -- rising clock edge
            if frame_cntr_temp = 8 and frame_cntr /= 8 then
                data_deserialized <= (others => '0');
            elsif frame_cntr = 8 then
                data_deserialized(frame_cntr * 64 + 63 downto frame_cntr * 64) <= lane_data_in.data;
                data_deserialized((frame_cntr-1) * 64 + 63 downto 0) <= data_deserialized_temp((frame_cntr-1) * 64 + 63 downto 0);
            end if;
        end if;
    end process load_data_p;

    data_40mhz_p: process(lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            demux_data_o <= data_deserialized;
        end if;
    end process;


end architecture rtl;
