library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;
use work.math_pkg.all;

entity BX_delay_alignment is
    generic(
        MAX_LATENCY_360 : integer := 255
    );
    port(
        clk360     : in  std_logic;
        rst360     : in  std_logic;
        clk40      : in  std_logic;
        rst40      : in  std_logic;

        ref_bx_nr      : bctr_t;
        ctrs_in        : in  ttc_stuff_t;
        delay_lkd      : out std_logic;
        delay_val      : out std_logic_vector(log2c(MAX_LATENCY_360) - 1 downto 0)
    );
end entity BX_delay_alignment;

architecture RTL of BX_delay_alignment is

    type state_t is (chasing, stop);
    signal state         : state_t := chasing;
    signal delay_int     : std_logic_vector(log2c(MAX_LATENCY_360) - 1 downto 0);
    signal counter       : unsigned(log2c(MAX_LATENCY_360) - 1 downto 0) :=  (others => '0');
    signal counter_int1  : unsigned(log2c(MAX_LATENCY_360) - 1 downto 0) :=  to_unsigned(MAX_LATENCY_360, log2c(MAX_LATENCY_360));
    signal counter_int2  : unsigned(log2c(MAX_LATENCY_360) - 1 downto 0) :=  to_unsigned(MAX_LATENCY_360, log2c(MAX_LATENCY_360));
    
    signal locked_int1   : std_logic;
    signal locked_int2   : std_logic;

begin
    -- TODO improve FSM
    process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                counter      <= (others => '0');
                counter_int1 <= to_unsigned(MAX_LATENCY_360, log2c(MAX_LATENCY_360));
                locked_int1 <= '0';
                state        <= chasing;
            else
                case state is
                    when chasing =>
                        if ctrs_in.bctr = std_logic_vector(to_unsigned(0,12)) and ctrs_in.pctr = "0000"  then
                            locked_int1 <= '0';
                            counter <= (others => '0');
                        elsif ref_bx_nr =  std_logic_vector(to_unsigned(0,12))  then
                            counter_int1 <= counter;
                            locked_int1 <= '1';
                            state        <= stop;
                        else
                            locked_int1 <= '0';
                            counter <= counter + 1;
                        end if;
                    when stop =>
                        counter <= (others => '0');
                        if rst360 = '1' then
                            locked_int1 <= '0';
                            state   <= chasing;
                        end if;
                end case;
            end if;
        end if;
    end process;

    reg_counter_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                counter_int2 <= to_unsigned(MAX_LATENCY_360, log2c(MAX_LATENCY_360));
                locked_int2  <= '0';
            else
                counter_int2 <= counter_int1;
                locked_int2  <= locked_int1;
            end if;
        end if;
    end process reg_counter_p;

    delay_lkd <= locked_int2;
    delay_val <= std_logic_vector(counter_int2);


end architecture RTL;
