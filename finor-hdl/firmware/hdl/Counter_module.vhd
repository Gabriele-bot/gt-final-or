library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;

use work.P2GT_finor_pkg.all;

entity Counter_module is
    generic(
        BEGIN_LUMI_BIT : integer := 18;
        SYNC_CTRS_OUT  : boolean := FALSE
    );
    port(
        clk40          : in  std_logic;
        rst40          : in  std_logic;
        ctrs_in        : in  ttc_stuff_t;
        ctrs_out       : out ttc_stuff_t;
        bc0_i          : in  std_logic;
        ec0_i          : in  std_logic;
        oc0_i          : in  std_logic;
        test_en_i      : in  std_logic;
        bx_nr          : out p2gt_bctr_t;
        event_nr       : out p2gt_ectr_t;
        orbit_nr       : out p2gt_octr_t;
        lumi_sec_nr    : out p2gt_lsctr_t;
        begin_lumi_sec : out std_logic;
        end_lumi_sec   : out std_logic;
        test_en_o      : out std_logic
    );
end entity Counter_module;

architecture RTL of Counter_module is

    signal bx_ctr                  : p2gt_bctr_t  := (others => '0');
    signal e_ctr                   : p2gt_ectr_t  := (others => '0');
    signal o_ctr                   : p2gt_octr_t  := (others => '0');
    signal ls_ctr                  : p2gt_lsctr_t := (others => '0');
    signal l1a                     : std_logic;
    signal o_ctrbls_temp, o_ctrbls : std_logic; --bit lumi section (in the orbit counter)

    signal begin_lumi_sec_int : std_logic;
    signal end_lumi_sec_int   : std_logic;
    signal test_en_int        : std_logic;

begin

    process(clk40)
    begin
        if rising_edge(clk40) then
            l1a    <= ctrs_in.l1a;
            bx_ctr <= ctrs_in.bctr;     --TODO check clk cross here (the signals is 360 synchronous, yet I'm using it at 40...)
        end if;
    end process;

    sync_g : if SYNC_CTRS_OUT generate
        process(clk40)
        begin
            if rising_edge(clk40) then
                ctrs_out <= ctrs_in;
            end if;
        end process;
    else generate
        ctrs_out <= ctrs_in;
    end generate;

    octr_p : process(clk40)
    begin
        if rising_edge(clk40) then
            if oc0_i = '1' or rst40 = '1' then
                o_ctr <= (others => '0');
            elsif unsigned(bx_ctr) = LHC_BUNCH_COUNT - 1 then
                o_ctr <= std_logic_vector(unsigned(o_ctr) + 1);
            end if;
        end if;
    end process;

    ectr_p : process(clk40)
    begin
        if rising_edge(clk40) then
            if ec0_i = '1' or rst40 = '1' then
                e_ctr <= (others => '0');
            elsif l1a = '1' then
                e_ctr <= std_logic_vector(unsigned(e_ctr) + 1);
            end if;
        end if;
    end process;

    o_ctrbls <= o_ctr(BEGIN_LUMI_BIT);

    process(clk40)
    begin
        if rising_edge(clk40) then
            o_ctrbls_temp <= o_ctrbls;
        end if;
    end process;

    ls_ctr_resize_g : if o_ctr'high - BEGIN_LUMI_BIT >= 31 generate
        ls_ctr <= o_ctr(BEGIN_LUMI_BIT + 31 downto BEGIN_LUMI_BIT);
    else generate
        ls_ctr <= (o_ctr'high - BEGIN_LUMI_BIT downto 0 => o_ctr(o_ctr'high downto BEGIN_LUMI_BIT), others => '0');
    end generate;

    begin_lumi_sec_int <= '1' when o_ctrbls_temp /= o_ctrbls else '0';

    process(o_ctr, bx_ctr)
    begin
        if (and o_ctr(BEGIN_LUMI_BIT - 1 downto 0) = '1') and (unsigned(bx_ctr) = LHC_BUNCH_COUNT - 1) then
            end_lumi_sec_int <= '1';
        else
            end_lumi_sec_int <= '0';
        end if;
    end process;

    process(clk40)
    begin
        if rising_edge(clk40) then
            if rst40 = '1' then
                test_en_int <= '0';
            elsif test_en_i then
                test_en_int <= '1';
            elsif unsigned(bx_ctr) = LHC_BUNCH_COUNT - 1 then
                test_en_int <= '0';
            end if;
        end if;
    end process;

    bx_nr       <= bx_ctr;
    event_nr    <= e_ctr;
    orbit_nr    <= o_ctr;
    lumi_sec_nr <= ls_ctr;

    begin_lumi_sec <= begin_lumi_sec_int;
    end_lumi_sec   <= end_lumi_sec_int;
    test_en_o      <= test_en_int;

end architecture RTL;
