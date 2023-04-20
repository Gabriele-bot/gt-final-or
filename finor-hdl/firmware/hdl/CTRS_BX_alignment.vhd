library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.emp_data_types.all;
use work.emp_project_decl.all;
use work.ipbus_decode_SLR_FinOR_unit.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

use work.math_pkg.all;

entity CTRS_BX_alignment is
    generic(
        MAX_LATENCY_360 : integer := 255;
        OUT_REG_40      : boolean := FALSE
    );
    port(
        clk360     : in  std_logic;
        rst360     : in  std_logic;
        clk40      : in  std_logic;
        rst40      : in  std_logic;

        ref_bx_nr      : bctr_t;
        ctrs_in        : in  ttc_stuff_t;
        ctrs_out       : out ttc_stuff_t;
        delay_val      : out std_logic_vector(log2c(MAX_LATENCY_360) - 1 downto 0)
    );
end entity CTRS_BX_alignment;

architecture RTL of CTRS_BX_alignment is

    type state_t is (idle, chasing, stop);
    signal state : state_t := idle;
    signal ctrs_del_arr  : ttc_stuff_array(MAX_LATENCY_360 downto 0) := (others => TTC_STUFF_NULL);
    signal counter       : unsigned(log2c(MAX_LATENCY_360) - 1 downto 0) :=  (others => '0');
    signal counter_int1  : unsigned(log2c(MAX_LATENCY_360) - 1 downto 0) :=  to_unsigned(200, log2c(MAX_LATENCY_360));
    signal counter_int2  : unsigned(log2c(MAX_LATENCY_360) - 1 downto 0) :=  to_unsigned(200, log2c(MAX_LATENCY_360));

begin

    ctrs_del_arr(0) <= ctrs_in;
    process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1'  then
                ctrs_del_arr(ctrs_del_arr'high downto 1) <= (others => TTC_STUFF_NULL);
            else
                ctrs_del_arr(ctrs_del_arr'high downto 1) <= ctrs_del_arr(ctrs_del_arr'high - 1 downto 0);
            end if;
        end if;
    end process;

    process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                counter     <= (others => '0');
                counter_int1 <= to_unsigned(200, log2c(MAX_LATENCY_360));
                state <= idle;
            else
                case state is
                    when idle =>
                        if ref_bx_nr /=  ctrs_del_arr(to_integer(counter)).bctr  then
                            counter <= counter + 1;
                            state <= chasing;
                        end if;
                    when chasing =>
                        if (unsigned(ref_bx_nr)) =  unsigned(ctrs_del_arr(to_integer(counter)).bctr)  then
                            state <= stop;
                            counter_int1 <= counter;
                        else
                            counter <= counter + 1;
                            state <= chasing;
                        end if;
                    when stop =>
                        state <= stop;
                        if rst360 = '1' then
                           state <= idle; 
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    reg_counter_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                counter_int2 <= to_unsigned(200, log2c(MAX_LATENCY_360));
            else
                counter_int2 <= counter_int1;
            end if;
        end if;
    end process reg_counter_p;
    
    
    delay_val <= std_logic_vector(counter_int2);
    
    out_reg_g : if OUT_REG_40 generate
        process(clk40)
        begin
            if rising_edge(clk40) then
            ctrs_out <= ctrs_del_arr(to_integer(counter_int2));
            end if;
        end process;
    else generate
        ctrs_out <= ctrs_del_arr(to_integer(counter_int2));
    end generate;


end architecture RTL;
