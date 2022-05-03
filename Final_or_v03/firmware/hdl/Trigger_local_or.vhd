
-- Description: Local or of the two SLR_modules

-- Created by Gabriele Bortolato 25-04-2022


-- Resources utilization
-- |       | Synth |  Impl |
-- |-------|-------|-------|
-- | LUT   |  9    |  9    |
-- | FF    |  8    |  8    |
----------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.FinOR_pkg.all;

use work.P2GT_monitor_pkg.all;
use work.pre_scaler_pkg.all;

use work.math_pkg.all;

entity Trigger_local_or is
    port(
        clk360  : in std_logic;
        rst360  : in std_logic;
        q       : out ldata(0 downto 0);             -- data out
        trgg_0  : in std_logic_vector(N_TRIGG-1 downto 0);
        trgg_1  : in std_logic_vector(N_TRIGG-1 downto 0)

    );
end entity Trigger_local_or;

architecture RTL of Trigger_local_or is
    

begin

    process(clk360)
    begin
        if rising_edge(clk360) then
            if (rst360 = '1') then
                q(0).data  <= (others => '0');
                q(0).valid  <= '0';
                q(0).start  <= '0';
                q(0).strobe <= '1';
            else
                q(0).data(N_TRIGG -1 downto 0)  <= trgg_0 or trgg_1;
                q(0).data(63 downto N_TRIGG) <= (others => '0');
                q(0).valid  <= '1';
                q(0).start  <= '1';
                q(0).strobe <= '1';
            end if;
	    end if;


    end process;

end architecture RTL;

