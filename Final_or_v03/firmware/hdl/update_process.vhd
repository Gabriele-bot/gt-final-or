
-- Desription:
-- Update process for prescalers for algorithms in in P2GT FinalOR

-- Created by Gabriele Bortolato 14-03-2022
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware)

-- Version-history:
-- GB : make some modifications

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity update_process is
    generic(
        WIDTH      : integer := 24;
        INIT_VALUE : std_logic_vector(31 DOWNTO 0) := X"00000064" --1.00
    );
    port(
        clk                  : in std_logic;
        request_update_pulse : in std_logic;
        update_pulse         : in std_logic;
        data_i               : in std_logic_vector(WIDTH-1 downto 0);
        data_o               : out std_logic_vector(WIDTH-1 downto 0)
    );
end update_process;

architecture rtl of update_process is
    signal request_ff : std_logic := '0';
    signal data_int   : std_logic_vector(WIDTH-1 downto 0) := INIT_VALUE(WIDTH-1 downto 0);
begin

    request_ff_p: process (clk)
    begin
        if rising_edge(clk) then
            if request_update_pulse = '1' then
                request_ff <= '1'; -- set if update is requested
            elsif update_pulse = '1' then
                request_ff <= '0'; -- clear with "update" pulse (e.g.: begin of lumi-section)
            end if;
        end if;
    end process request_ff_p;

    update_factor_p: process (clk)
    begin
        if rising_edge(clk) then
            if request_ff = '1' and update_pulse = '1' then
                data_int <= data_i; -- load data_i to data_int, if requested and "update" pulse (e.g.: begin of lumi-section)
            end if;
        end if;
    end process update_factor_p;

    data_o <= data_int;

end architecture rtl;
