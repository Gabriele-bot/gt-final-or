-- GB 29-07-2022: new version, deserializer synchronized with link_valid.
library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.VComponents.all;

use work.emp_data_types.all;
use work.emp_ttc_decl.all;
entity In_deser is
    generic(
        OUT_REG : boolean := TRUE
    );
    port(
        clk360             : in std_logic;
        lhc_clk            : in std_logic;
        lhc_rst            : in std_logic;
        lane_data_in       : in lword;
        rst_err            : in std_logic;
        align_err_o        : out std_logic;
        demux_data_o       : out std_logic_vector(9*64-1 downto 0)
    );
end In_deser;

architecture rtl of In_deser is

    signal data_deserialized      : std_logic_vector(9*64 - 1 downto 0);
    signal data_deserialized_temp : std_logic_vector(8*64 - 1 downto 0);

    signal data_in_valid_del_arr  : std_logic_vector(9 downto 0);

    signal frame_cntr,  frame_cntr_temp: integer range 0 to 8;

    signal metadata  : std_logic_vector(3 downto 0);
    signal align_err : std_logic := '0';

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


    out_reg_g : if OUT_REG generate
        data_40mhz_p: process(lhc_clk)
        begin
            if rising_edge(lhc_clk) then
                demux_data_o <= data_deserialized;
            end if;
        end process;
    else generate
        demux_data_o <= data_deserialized;
    end generate;
    
    
    metadata <= lane_data_in.start_of_orbit & lane_data_in.start & lane_data_in.last & lane_data_in.valid;

    align_check_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if align_err = '1' then
                if rst_err = '1' then
                    align_err <= '0';
                end if;
            else
                case frame_cntr is
                    when 0 =>
                        if metadata = "-0-1" or metadata = "--11" then
                            align_err <=  '1';
                        else
                            align_err <=  '0';
                        end if;
                    when 8 =>
                        if metadata = "--01" or metadata = "-1-1" then
                            align_err <=  '1';
                        else
                            align_err <=  '0';
                        end if;
                    when others =>
                        if metadata = "--11" or metadata = "-1-1" then
                            align_err <=  '1';
                        else
                            align_err <=  '0';
                        end if;
                end case;
            end if;
        end if;
    end process align_check_p;
    
    align_err_o <= align_err;

end architecture rtl;
