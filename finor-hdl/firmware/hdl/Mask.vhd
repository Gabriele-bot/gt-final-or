--=================================================================
-- Trigger bits evaluation
-- Comput N trigger bits starting from an algobits vector and N trigger masks,
-- the i-th mask selects which algobits contribute to the i-th trigger
-- The masks are updated only at the start of lumisection if the request update is asserted 
--=================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.P2GT_finor_pkg.all;

entity Mask is
    generic(
        NR_ALGOS : natural := N_SLR_ALGOS;
        OUT_REG  : boolean := TRUE
    );
    port(
        clk                        : in  std_logic;
        algos_in                   : in  std_logic_vector(NR_ALGOS - 1 downto 0);
        valid_in                   : in  std_logic;
        masks                      : in  mask_arr;
        request_masks_update_pulse : in  std_logic;
        update_pulse               : in  std_logic;
        trigger_out                : out std_logic_vector(N_TRIGG - 1 downto 0);
        valid_out                  : out std_logic
    );
end entity Mask;

architecture RTL of Mask is

    constant PASS_THROUGH_MASK : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '1');

    signal trigger_s : std_logic_vector(N_TRIGG - 1 downto 0) := (others => '0');
    signal valid_s   : std_logic;
    signal masks_int : mask_arr  := (others  => (others => '0')); -- array of N_TRIGG standard logic vector
begin
    
    -----------------------------------------------------------------------------------
    ---------------MASK UPDATE---------------------------------------------------------
    -----------------------------------------------------------------------------------
    gen_masks_update_l : for i in 0 to N_TRIGG - 1 generate
        masks_update_i : entity work.update_process
            generic map(
                WIDTH      => NR_ALGOS,
                INIT_VALUE => PASS_THROUGH_MASK
            )
            port map(
                clk                  => clk,
                request_update_pulse => request_masks_update_pulse,
                update_pulse         => update_pulse,
                data_i               => masks(i)(NR_ALGOS - 1 downto 0),
                data_o               => masks_int(i)(NR_ALGOS - 1 downto 0)
            );
    end generate;
    
    -----------------------------------------------------------------------------------
    ---------------TRIGGERS EVALUATION-------------------------------------------------
    -----------------------------------------------------------------------------------
    trigger_out_l : for i in 0 to N_TRIGG - 1 generate
        trigger_s(i) <= or (algos_in and masks_int(i)(NR_ALGOS - 1 downto 0));
    end generate;

    valid_s <= valid_in;

    out_reg_g : if OUT_REG generate
        process(clk)
        begin
            if rising_edge(clk) then
                trigger_out <= trigger_s;
                valid_out   <= valid_s;
            end if;
        end process;
    else generate
        trigger_out <= trigger_s;
        valid_out   <= valid_s;
    end generate;

end architecture RTL;
