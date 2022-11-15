library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;

entity Counter_module is
    generic(
        BEGIN_LUMI_BIT : integer := 18
    );
    port(
        lhc_clk  : in std_logic;
        lhc_rst  : in std_logic;
        ctrs_in  : in ttc_stuff_t;
        bc0            : out std_logic;
        ec0            : out std_logic;
        oc0            : out std_logic;
        bx_nr          : out bctr_t;
        event_nr       : out eoctr_t;
        orbit_nr       : out eoctr_t;
        lumi_sec_nr    : out eoctr_t;
        begin_lumi_sec : out std_logic;
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
    signal test_en_int        : std_logic;
    
begin
    
    
    l1a    <= ctrs_in.l1a;
    bx_cnt <= ctrs_in.bctr;
    
    

    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            case (ctrs_in.ttc_cmd) is
                when TTC_BCMD_BC0 =>
                    bc0_s <= '1';
                    ec0_s <= '0';
                    oc0_s <= '0';
                when TTC_BCMD_EC0 =>
                    bc0_s <= '0';
                    ec0_s <= '1';
                    oc0_s <= '0';
                when TTC_BCMD_OC0 =>
                    bc0_s <= '0';
                    ec0_s <= '0';
                    oc0_s <= '1';
                when others =>
                    bc0_s <= '0';
                    ec0_s <= '0';
                    oc0_s <= '0';
            end case;
        end if;
    end process;

    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            if oc0_s = '1' then
                o_cnt <= (others => '0');
            elsif unsigned(bx_cnt) = LHC_BUNCH_COUNT-1 then
                o_cnt <= std_logic_vector(unsigned(o_cnt) + 1);
            end if;
        end if;
    end process;
    
    o_cntbls <= o_cnt(BEGIN_LUMI_BIT);
    
    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            if ec0_s = '1' then
                e_cnt  <= (others => '0');
            elsif l1a = '1' then
                e_cnt <= std_logic_vector(unsigned(e_cnt) + 1);
            end if;
        end if;
    end process;
    
    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
            if ec0_s = '1' then
                ls_cnt <= (others => '0');
            else
                ls_cnt(o_cnt'high - BEGIN_LUMI_BIT downto 0) <=  o_cnt(o_cnt'high downto BEGIN_LUMI_BIT);
                ls_cnt(o_cnt'high  downto o_cnt'high - BEGIN_LUMI_BIT + 1 ) <= (others => '0');
            end if;
            o_cntbls_temp <= o_cntbls;
            if o_cntbls_temp /= o_cntbls then -- toggle of o_cnt(BEGIN_LUMI_BIT)
                begin_lumi_sec_int <= '1';
            else 
                begin_lumi_sec_int <= '0';
            end if;
        end if;
    end process;
    
    process (lhc_clk)
    begin
        if rising_edge(lhc_clk) then
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
    test_en        <= test_en_int;
    


end architecture RTL;
