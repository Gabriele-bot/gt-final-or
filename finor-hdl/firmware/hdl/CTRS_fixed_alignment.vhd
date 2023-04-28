library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;
use work.math_pkg.all;

entity CTRS_fixed_alignment is
    generic(
        MAX_LATENCY_360 : integer := 255;
        DELAY_OFFSET    : integer := 0
    );
    port(
        clk360     : in  std_logic;
        rst360     : in  std_logic;
        clk40      : in  std_logic;
        rst40      : in  std_logic;
        
        ctrs_delay_lkd : in  std_logic;
        ctrs_delay_val : in  std_logic_vector(log2c(MAX_LATENCY_360) - 1 downto 0);

        ctrs_in        : in  ttc_stuff_t;
        ctrs_out       : out ttc_stuff_t
    );
end entity CTRS_fixed_alignment;

architecture RTL of CTRS_fixed_alignment is

    --    signal ctrs_del_arr : ttc_stuff_array(MAX_LATENCY_360 + DELAY_OFFSET downto 0) := (others => TTC_STUFF_NULL);
    --    
    --begin
    --    
    --    ctrs_del_arr(0) <= ctrs_in;
    --    process(clk360)
    --    begin
    --        if rising_edge(clk360) then
    --            ctrs_del_arr(ctrs_del_arr'high downto 1) <= ctrs_del_arr(ctrs_del_arr'high - 1 downto 0);
    --            --ctrs_reg <= ctrs_del_arr(to_integer(unsigned(ctrs_delay_val)) + DELAY_OFFSET);
    --        end if;
    --    end process;
    --    
    --    ctrs_out <= ctrs_del_arr(to_integer(unsigned(ctrs_delay_val)) + DELAY_OFFSET);

    signal ctrs_in_flatten  : std_logic_vector(8+1+12+4 - 1 downto 0);
    signal ctrs_out_flatten : std_logic_vector(8+1+12+4 - 1 downto 0);
    signal delay            : std_logic_vector(log2c(MAX_LATENCY_360 + DELAY_OFFSET) - 1 downto 0);

begin

    ctrs_in_flatten <= ctrs_in.ttc_cmd & ctrs_in.l1a & ctrs_in.bctr & ctrs_in.pctr;
    
    delay <= std_logic_vector(resize(unsigned(ctrs_delay_val), log2c(MAX_LATENCY_360 + DELAY_OFFSET)) + to_unsigned(DELAY_OFFSET, log2c(MAX_LATENCY_360 + DELAY_OFFSET)) - 1);
    -- minus 1 is due to the ring buffer delay element that will register the output resulting in an increased delay value
    
    delay_line_i : entity work.delay_element_ringbuffer
        generic map(
            DATA_WIDTH         => 8+1+12+4,
            MAX_DELAY          => MAX_LATENCY_360 + DELAY_OFFSET,
            RESET_WITH_NEW_DEL => FALSE
        )
        port map(
            clk       => clk360,
            rst       => rst360,
            data_i    => ctrs_in_flatten,
            data_o    => ctrs_out_flatten,
            delay_lkd => ctrs_delay_lkd,
            delay     => delay
        );
        
    ctrs_out.ttc_cmd  <= ctrs_out_flatten(8+1+12+4 - 1 downto 1+12+4);
    ctrs_out.l1a      <= ctrs_out_flatten(12+4                      );
    ctrs_out.bctr     <= ctrs_out_flatten(12+4     - 1 downto 4     );
    ctrs_out.pctr     <= ctrs_out_flatten(4        - 1 downto 0     );
    


end architecture RTL;
