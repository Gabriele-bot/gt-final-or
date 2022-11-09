library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--use work.FinOR_pkg.all;
use work.P2GT_finor_pkg.all;

entity Mask is
    generic(
        NR_ALGOS : natural := 64*9;
        OUT_REG  : boolean := TRUE
    );
    port(
        clk                  : in std_logic;
        algos_in             : in std_logic_vector(NR_ALGOS - 1 downto 0);
        veto_in              : in std_logic_vector(NR_ALGOS - 1 downto 0);
        masks                : in mask_arr;
        request_masks_update_pulse : in std_logic;
        request_veto_update_pulse  : in std_logic;
        update_pulse               : in std_logic;
        trigger_out           : out std_logic_vector(N_TRIGG -1 downto 0);
        trigger_with_veto_out : out std_logic_vector(N_TRIGG -1 downto 0)
    );
end entity Mask;

architecture RTL of Mask is

    constant PASS_THROUGH_MASK : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '1');
    constant NULL_VETO_MASK    : std_logic_vector(NR_ALGOS - 1 downto 0) := (others => '0');

    signal trigger_s           : std_logic_vector(N_TRIGG -1 downto 0) := (others => '0');
    signal trigger_with_veto_s : std_logic_vector(N_TRIGG -1 downto 0) := (others => '0');
    signal masks_int : mask_arr;
    signal veto_int  : std_logic_vector(NR_ALGOS - 1 downto 0);

begin

    gen_masks_update_l : for i in 0 to N_TRIGG - 1 generate
        masks_update_i: entity work.update_process
            generic map(
                WIDTH      => NR_ALGOS,
                INIT_VALUE => PASS_THROUGH_MASK
            )
            port map(
                clk                  => clk,
                request_update_pulse => request_masks_update_pulse,
                update_pulse         => update_pulse,
                data_i               => masks(i),
                data_o               => masks_int(i)
            );
    end generate;

    veto_update_i: entity work.update_process
        generic map(
            WIDTH      => NR_ALGOS,
            INIT_VALUE => NULL_VETO_MASK
        )
        port map(
            clk                  => clk,
            request_update_pulse => request_veto_update_pulse,
            update_pulse         => update_pulse,
            data_i               => veto_in,
            data_o               => veto_int
        );

    trigger_out_l : for i in 0 to N_TRIGG -1 generate
        trigger_s(i)           <= or (algos_in and masks_int(i));
        trigger_with_veto_s(i) <= (or (algos_in and masks_int(i))) and (nor veto_in);
    end generate;


    out_reg_g : if OUT_REG generate
        process(clk)
        begin
            if rising_edge(clk) then
                trigger_out           <= trigger_s;
                trigger_with_veto_out <= trigger_with_veto_s;
            end if;
        end process;
    else generate
        trigger_out           <= trigger_s;
        trigger_with_veto_out <= trigger_with_veto_s;
    end generate;

end architecture RTL;
