library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_data_types.all;
use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

entity mux is
    port(
        clk360      : in std_logic;
        rst360      : in std_logic;
        bctr        : in  bctr_t;
        -- input
        input_40MHz : in std_logic_vector(64*9-1 downto 0);
        valid_in    : in std_logic;
        -- output
        output_data : out lword
    );
end mux;

architecture arch of mux is

    signal reset_del : std_logic;
    signal valid_del : std_logic;

    signal s_out            : std_logic_vector(63 downto 0);

    signal frame_cntr, frame_cntr_del  : integer range 0 to 8;

    signal input_reg       : std_logic_vector(64*9-1 downto 0);
    signal output_link_reg : lword;

begin
    
    del_p : process (clk360)
    begin
        if rising_edge(clk360) then -- rising clock edge
            reset_del <= rst360;
            valid_del <= valid_in;
        end if;
    end process del_p;


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
            frame_cntr_del <= frame_cntr;
        end if;
    end process frame_counter_p;

    reg_input_p : process (clk360)
    begin
        if rising_edge(clk360) then
            if frame_cntr = 0 and valid_in = '1' then
                input_reg <= input_40MHz;
            end if;
        end if;
    end process reg_input_p;


    process(frame_cntr_del,input_reg)
    begin
        s_out        <=  input_reg(64*(frame_cntr_del+1)-1  downto 64*(frame_cntr_del));
    end process;

    output_link_reg.valid          <= valid_del;
    output_link_reg.start          <= '1'   when frame_cntr_del = 0 and valid_del = '1' else '0';
    output_link_reg.last           <= '1'   when frame_cntr_del = 8 and valid_del = '1' else '0';
    output_link_reg.start_of_orbit <= '1'   when frame_cntr_del = 0 and valid_del = '1' and (bctr = std_logic_vector(to_unsigned(0,12))) else '0';
    output_link_reg.data           <= s_out when valid_del = '1' else (others => '0');

    sync : process(clk360)
    begin
        if rising_edge(clk360) then
            if (reset_del = '1')then
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
