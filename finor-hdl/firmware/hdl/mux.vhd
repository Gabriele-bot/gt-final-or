library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_data_types.all;

entity mux is
    port(
        clk360      : in std_logic;
        rst360      : in std_logic;
        lhc_clk     : in std_logic;
        lhc_rst     : in std_logic; -- res 40 MHz
        -- input
        input_40MHz : in std_logic_vector(64*9-1 downto 0);
        valid_in    : in std_logic;
        -- output
        output_data : out lword
    );
end mux;

architecture arch of mux is
    
    signal valid_in_del_arr : std_logic_vector(10 downto 0);
    signal s_out            : std_logic_vector(63 downto 0);

    signal frame_cntr  : integer range 0 to 8;

    signal output_link_reg : lword;

begin
    
    valid_in_del_arr(0) <= valid_in;
    del_valid_p : process (clk360)
    begin
        if rising_edge(clk360) then -- rising clock edge
            valid_in_del_arr(10 downto 1) <=  valid_in_del_arr(9 downto 0);
        end if;
    end process del_valid_p;
    

    -- frame counter
    frame_counter_p : process (clk360)
    begin
        if rising_edge(clk360) then -- rising clock edge
            if valid_in = '0' then
                frame_cntr <= 0;
            elsif frame_cntr < 8 then
                frame_cntr <= frame_cntr + 1;
            else
                frame_cntr <= 0;
            end if;
        end if;
    end process frame_counter_p;


    process(frame_cntr,input_40MHz)
    begin
        s_out        <=  input_40MHz(64*(frame_cntr+1)-1  downto 64*(frame_cntr));
    end process;
    
    output_link_reg.valid          <= valid_in_del_arr(9);
    output_link_reg.start          <= '1' when frame_cntr = 0 and valid_in_del_arr(9) = '1' else '0';
    output_link_reg.last           <= '1' when frame_cntr = 8 and valid_in_del_arr(9) = '1' else '0';
    output_link_reg.start_of_orbit <= '1' when frame_cntr = 0 and valid_in_del_arr(9) = '1' and valid_in_del_arr(10) = '0' else '0';
    output_link_reg.data           <= s_out when valid_in_del_arr(9) = '1' else (others => '0');

    sync : process(clk360)
    begin
        if rising_edge(clk360) then
            if (rst360 = '1' or lhc_rst = '1')then
                output_data.data           <= (others => '0');
                output_data.valid          <= '0';
                output_data.start_of_orbit <= '0';
                output_data.start          <= '0';
                output_data.last           <= '0';
            else
                output_data <= output_link_reg;
            end if;
        end if;
    end process;

end architecture;
