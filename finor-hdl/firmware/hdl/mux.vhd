library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_data_types.all;
use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

entity mux is
    generic(
        TMUX2 : boolean := False
    );
    port(
        clk360      : in  std_logic;
        rst360      : in  std_logic;
        clk40       : in  std_logic;
        rst40       : in  std_logic;
        bctr        : in  bctr_t;
        -- input
        input_40MHz : in  std_logic_vector(64 * 9 - 1 downto 0);
        valid_in    : in  std_logic;
        -- output
        output_data : out lword
    );
end mux;

architecture arch of mux is

    signal reset_d  : std_logic := '0';
    signal reset_dd : std_logic := '0';
    signal valid_d  : std_logic := '0';
    signal valid_dd : std_logic := '0';

    signal s_out : std_logic_vector(63 downto 0);

    signal frame_cntr   : integer range 0 to 17 := 0;
    signal frame_cntr_d : integer range 0 to 17 := 0;

    signal input_40MHz_reg : std_logic_vector(64 * 9 - 1 downto 0);
    signal valid_40MHz_reg : std_logic;

    signal input_360_reg   : std_logic_vector(64 * 9 - 1 downto 0);
    signal valid_360_reg   : std_logic;
    signal input_reg_2     : std_logic_vector(64 * 9 - 1 downto 0);
    signal output_link_reg : lword;

begin

    in_reg : process(clk40)
    begin
        if rising_edge(clk40) then
            input_40MHz_reg <= input_40MHz;
            valid_40MHz_reg <= valid_in;
        end if;
    end process in_reg;

    del_p : process(clk360)
    begin
        if rising_edge(clk360) then
            reset_d  <= rst360;
            reset_dd <= reset_d;
            valid_d  <= valid_in;
            valid_dd <= valid_d;
        end if;
    end process del_p;

    -- frame counter
    tmux2_frame_counter_g : if TMUX2 generate
        frame_counter_TM2_p : process(clk360)
        begin
            if rising_edge(clk360) then -- rising clock edge
                if valid_40MHz_reg = '0' then
                    frame_cntr <= 0;
                elsif frame_cntr < 17 then
                    frame_cntr <= frame_cntr + 1;
                else
                    frame_cntr <= 0;
                end if;
            end if;
        end process frame_counter_TM2_p;
    else generate
        frame_counter_p : process(clk360)
        begin
            if rising_edge(clk360) then
                if valid_40MHz_reg = '0' then
                    frame_cntr <= 0;
                elsif frame_cntr < 8 then
                    frame_cntr <= frame_cntr + 1;
                else
                    frame_cntr <= 0;
                end if;
            end if;
        end process frame_counter_p;
    end generate;

    reg_input_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if (frame_cntr = 0 or frame_cntr = 9) and valid_40MHz_reg = '1' then
                input_360_reg <= input_40MHz_reg;
            end if;
            valid_360_reg <= valid_40MHz_reg;
            frame_cntr_d  <= frame_cntr;
        end if;
    end process reg_input_p;

    tmux2_out_g : if TMUX2 generate
        process(frame_cntr_d, input_360_reg)
        begin
            if frame_cntr_d >= 9 then
                s_out <= input_360_reg(64 * (frame_cntr_d - 9 + 1) - 1 downto 64 * (frame_cntr_d - 9));
            else
                s_out <= input_360_reg(64 * (frame_cntr_d + 1) - 1 downto 64 * (frame_cntr_d));
            end if;
        end process;

        output_link_reg.strobe         <= not rst360;
        output_link_reg.valid          <= valid_360_reg;
        output_link_reg.start          <= '1' when frame_cntr_d = 0 and valid_360_reg = '1' else '0';
        output_link_reg.last           <= '1' when frame_cntr_d = 17 and valid_360_reg = '1' else '0';
        output_link_reg.start_of_orbit <= '1' when frame_cntr_d = 0 and valid_360_reg = '1' and (bctr = std_logic_vector(to_unsigned(0, 12))) else '0';
        output_link_reg.data           <= s_out when valid_360_reg = '1' else (others => '0');
    else generate
        process(frame_cntr_d, input_360_reg)
        begin
            s_out <= input_360_reg(64 * (frame_cntr_d + 1) - 1 downto 64 * (frame_cntr_d));
        end process;
        output_link_reg.strobe         <= not rst360;
        output_link_reg.valid          <= valid_360_reg;
        output_link_reg.start          <= '1' when frame_cntr_d = 0 and valid_360_reg = '1' else '0';
        output_link_reg.last           <= '1' when frame_cntr_d = 8 and valid_360_reg = '1' else '0';
        output_link_reg.start_of_orbit <= '1' when frame_cntr_d = 0 and valid_360_reg = '1' and (bctr = std_logic_vector(to_unsigned(0, 12))) else '0';
        output_link_reg.data           <= s_out when valid_360_reg = '1' else (others => '0');
    end generate;

    sync : process(clk360)
    begin
        if rising_edge(clk360) then
            if (reset_dd = '1') then
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
