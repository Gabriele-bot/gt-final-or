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

entity ctrs_alignment is
    generic(
        MAX_LATENCY_360 : integer := 255;
        DELAY_OFFSET    : integer := 0 
    );
    port(
        clk360     : in  std_logic;
        rst360     : in  std_logic;
        clk40      : in  std_logic;
        rst40      : in  std_logic;
        
        ctrs_delay_val : in  std_logic_vector(log2c(MAX_LATENCY_360) - 1 downto 0);
        
        ctrs_in        : in  ttc_stuff_t;
        ctrs_out       : out ttc_stuff_t
    );
end entity ctrs_alignment;

architecture RTL of ctrs_alignment is
    
    signal ctrs_del_arr : ttc_stuff_array(MAX_LATENCY_360 downto 0) := (others => TTC_STUFF_NULL);
    
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
    
    ctrs_out <= ctrs_del_arr(to_integer(unsigned(ctrs_delay_val)) + DELAY_OFFSET);

end architecture RTL;
