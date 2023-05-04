--=================================================================
--Data Link Deserializer
--Transalte 64 bit@360 MHz data stream into 576 bit @ 40MHz data stream
--Alignemnt check is performed at the very last comparing the metadata against the expected values
--=================================================================
library ieee;
use ieee.std_logic_1164.all;

use work.emp_data_types.all;
use work.emp_ttc_decl.all;

entity Link_deserializer is
    generic(
        OUT_REG : boolean := TRUE
    );
    port(
        clk360             : in std_logic;
        rst360             : in std_logic;
        clk40              : in std_logic;
        rst40              : in std_logic;
        lane_data_in       : in lword;
        rst_err            : in std_logic;
        align_err_o        : out std_logic;
        demux_data_o       : out std_logic_vector(9*LWORD_WIDTH-1 downto 0);
        valid_out          : out std_logic
    );
end Link_deserializer;

architecture rtl of Link_deserializer is

    signal data_deserialized      : std_logic_vector(9*LWORD_WIDTH - 1 downto 0);
    signal data_deserialized_temp : std_logic_vector(8*LWORD_WIDTH - 1 downto 0);

    signal data_in_valid_del_arr  : std_logic_vector(9 downto 0);

    signal frame_cntr,  frame_cntr_temp: integer range 0 to 8;

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
                data_deserialized_temp(frame_cntr * LWORD_WIDTH + LWORD_WIDTH-1 downto frame_cntr * LWORD_WIDTH) <= lane_data_in.data;
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
                data_deserialized(frame_cntr * LWORD_WIDTH + LWORD_WIDTH-1 downto frame_cntr * 64) <= lane_data_in.data;
                data_deserialized((frame_cntr-1) * LWORD_WIDTH + LWORD_WIDTH-1 downto 0) <= data_deserialized_temp((frame_cntr-1) * LWORD_WIDTH + LWORD_WIDTH-1 downto 0);
            end if;
        end if;
    end process load_data_p;


    out_reg_g : if OUT_REG generate
        data_40mhz_p: process(clk40)
        begin
            if rising_edge(clk40) then
                if rst40 ='1' then
                    demux_data_o <= (others => '0');
                    valid_out    <= '0';
                else
                    demux_data_o <= data_deserialized;
                    valid_out    <= data_in_valid_del_arr(9);
                end if;
            end if;
        end process;
    else generate
        demux_data_o <= data_deserialized;
        valid_out    <= data_in_valid_del_arr(9);
    end generate;


    align_check_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if align_err = '1' then
                if rst_err = '1' or rst360 = '1' then
                    align_err <= '0';
                end if;
            else
                case frame_cntr is
                    when 0 =>
                        if lane_data_in.valid = '1' and  (lane_data_in.start = '0' or lane_data_in.last = '1') then -- (valid and no start) or (valid and last)
                            align_err <=  '1';
                        end if;
                        if data_in_valid_del_arr(1 downto 0) = "01" and  lane_data_in.start_of_orbit = '0' then -- (valid and no start of orbit) when valid rising edge
                            align_err <=  '1';
                        end if;
                    when 8 =>
                        if lane_data_in.valid = '1' and  (lane_data_in.start = '1' or lane_data_in.last = '0') then -- (valid and no last) or (valid and start)
                            align_err <=  '1';
                        end if;
                    when others =>
                        if lane_data_in.valid = '1' and  (lane_data_in.start = '1' or lane_data_in.last = '1') then -- valid and (start or last)
                            align_err <=  '1';
                        end if;
                end case;
            end if;
        end if;
    end process align_check_p;

    align_err_o <= align_err;

end architecture rtl;
