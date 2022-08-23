library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_data_types.all;

entity mux is
    port(
        clk         : in std_logic;
        rst         : in std_logic;
        lhc_clk     : in std_logic;
        lhc_rst     : in std_logic; -- res 40 MHz
        input_40MHz : in std_logic_vector(64*9-1 downto 0);
        -- output
        output_data : out lword
    );
end mux;

architecture arch of mux is

    signal s_out       : std_logic_vector(63 downto 0);

    constant N_SYNC_REGS : integer := 9;
    type reg_t is array (N_SYNC_REGS downto 0) of std_logic_vector(64*9-1 downto 0);
    signal input_regs  : reg_t;

    signal frame_cntr  : unsigned (3 downto 0); --counter for frame mux: 0 to 5

    attribute shreg_extract                   : string;
    attribute shreg_extract of input_regs     : signal is "no";

begin

    -- frame counter
    frame_counter: process (clk, lhc_rst)
    begin
        if (lhc_rst = '1') then
            frame_cntr <= "0000";      -- async. res
        elsif (rising_edge(clk)) then
            if (frame_cntr = "1000") then
                frame_cntr <= "0000";
            else
                frame_cntr <= frame_cntr + 1;
            end if;
        end if;
    end process frame_counter;

    input_regs(0) <= input_40MHz;

    sync_p : process (clk, lhc_rst)
    begin
        if (lhc_rst = '1') then
            input_regs(N_SYNC_REGS downto 1) <= (others => (others => '0'));
        elsif rising_edge(clk) then
            input_regs(N_SYNC_REGS downto 1) <= input_regs(N_SYNC_REGS - 1 downto 0);
        end if;
    end process sync_p;



    s_out        <=  input_regs(N_SYNC_REGS)(63  downto 0)    when frame_cntr = "0000" else
             input_regs(N_SYNC_REGS)(127 downto 64)   when frame_cntr = "0001" else
             input_regs(N_SYNC_REGS)(191 downto 128)  when frame_cntr = "0010" else
             input_regs(N_SYNC_REGS)(255 downto 192)  when frame_cntr = "0011" else
             input_regs(N_SYNC_REGS)(319 downto 256)  when frame_cntr = "0100" else
             input_regs(N_SYNC_REGS)(383 downto 320)  when frame_cntr = "0101" else
             input_regs(N_SYNC_REGS)(447 downto 384)  when frame_cntr = "0110" else
             input_regs(N_SYNC_REGS)(511 downto 448)  when frame_cntr = "0111" else
             input_regs(N_SYNC_REGS)(575 downto 512)  when frame_cntr = "1000" else
             ((others => '0'));


    sync : process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1' or lhc_rst = '1')then
                output_data.start  <= '0';
                output_data.strobe <= '0';
                output_data.valid  <= '0';
                output_data.data   <= (others => '0');
            else
                output_data.start  <= '1';
                output_data.strobe <= '1';
                output_data.valid  <= '1';
                output_data.data   <= s_out;
            end if;
        end if;
    end process;

    --out_p : process(s_out, rst, lhc_rst)
    --begin
    --    if (rst = '1' or lhc_rst = '1')then
    --        output_data.start  <= '0';
    --        output_data.strobe <= '0';
    --        output_data.valid  <= '0';
    --        output_data.data   <= (others => '0');
    --    else
    --        output_data.start  <= '1';
    --        output_data.strobe <= '1';
    --        output_data.valid  <= '1';
    --        output_data.data   <= s_out;
    --    end if;
    --end process;

end architecture;
