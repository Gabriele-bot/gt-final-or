library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;

entity Counter_module is
    generic(
        BEGIN_LUMI_BIT : integer := 18
    );
    port(
        clk40          : in  std_logic;
        rst40          : in  std_logic;
        ctrs_in        : in  ttc_stuff_t;
        bc0            : out std_logic;
        ec0            : out std_logic;
        oc0            : out std_logic;
        bx_nr          : out bctr_t;
        event_nr       : out eoctr_t;
        orbit_nr       : out eoctr_t;
        lumi_sec_nr    : out eoctr_t;
        begin_lumi_sec : out std_logic;
        end_lumi_sec   : out std_logic;
        test_en        : out std_logic
    );
end entity Counter_module;

architecture RTL of Counter_module is

    signal bx_cnt  : bctr_t  := (others => '0');
    signal e_cnt   : eoctr_t := (others => '0');
    signal o_cnt   : eoctr_t := (others => '0');
    signal ls_cnt  : eoctr_t := (others => '0');
    signal l1a    : std_logic;
    signal o_cntbls_temp,  o_cntbls : std_logic;

    signal bc0_s, oc0_s, ec0_s : std_logic := '0';

    signal begin_lumi_sec_int : std_logic;
    signal end_lumi_sec_int   : std_logic;
    signal test_en_int        : std_logic;

    signal test : std_logic;

begin

    process (clk40)
    begin
        if rising_edge(clk40) then
            l1a    <= ctrs_in.l1a;
            bx_cnt <= ctrs_in.bctr; --TODO check clk cross here (the signals is 360 synchronous, yet I'm using it at 40...)
        end if;
    end process;

    bc0_s       <= '1' when ctrs_in.ttc_cmd = TTC_BCMD_BC0  else '0';
    oc0_s       <= '1' when ctrs_in.ttc_cmd = TTC_BCMD_OC0  else '0';
    ec0_s       <= '1' when ctrs_in.ttc_cmd = TTC_BCMD_EC0  else '0';

    process (clk40)
    begin
        if rising_edge(clk40) then
            if oc0_s = '1' then
                o_cnt <= (others => '0');
            elsif unsigned(bx_cnt) = LHC_BUNCH_COUNT-1 then
                o_cnt <= std_logic_vector(unsigned(o_cnt) + 1);
            end if;
        end if;
    end process;

    process (clk40)
    begin
        if rising_edge(clk40) then
            if ec0_s = '1' then
                e_cnt  <= (others => '0');
            elsif l1a = '1' then
                e_cnt <= std_logic_vector(unsigned(e_cnt) + 1);
            end if;
        end if;
    end process;
    
    o_cntbls <= o_cnt(BEGIN_LUMI_BIT);

    process(clk40)
    begin
        if rising_edge(clk40) then
            o_cntbls_temp <= o_cntbls;
        end if;
    end process;

    ls_cnt(o_cnt'high - BEGIN_LUMI_BIT downto 0)                <=  o_cnt(o_cnt'high downto BEGIN_LUMI_BIT);
    ls_cnt(o_cnt'high  downto o_cnt'high - BEGIN_LUMI_BIT + 1 ) <= (others => '0');

    begin_lumi_sec_int <= '1' when o_cntbls_temp /= o_cntbls  else '0';

    process(o_cnt, bx_cnt)
    begin
        if  (and o_cnt(BEGIN_LUMI_BIT-1 downto 0) = '1') and (unsigned(bx_cnt) = LHC_BUNCH_COUNT-1) then
            end_lumi_sec_int <= '1';
        else
            end_lumi_sec_int <= '0';
        end if;
    end process;


    process (clk40)
    begin
        if rising_edge(clk40) then
            if ctrs_in.ttc_cmd = TTC_BCMD_TEST_ENABLE then
                test_en_int <= '1';
            elsif unsigned(bx_cnt) = LHC_BUNCH_COUNT-1 then
                test_en_int <= '0';
            end if;
        end if;
    end process;

    bc0 <= bc0_s;
    ec0 <= ec0_s;
    oc0 <= oc0_s;

    bx_nr          <= bx_cnt;
    event_nr       <= e_cnt;
    orbit_nr       <= o_cnt;
    lumi_sec_nr    <= ls_cnt;

    begin_lumi_sec <= begin_lumi_sec_int;
    end_lumi_sec   <= end_lumi_sec_int;
    test_en        <= test_en_int;



end architecture RTL;
