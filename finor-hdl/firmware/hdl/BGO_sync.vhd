-- Description:
-- SYNC BGOs module.

-- Created by Gabriele Bortolato 3-05-2023
-- Code based on the MP7 GT firmware (https://github.com/cms-l1-globaltrigger/mp7_ugt_legacy/tree/master/firmware) 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.emp_ttc_decl.all;

entity bgo_sync is
    port(
        clk360            : in  std_logic;
        rst360            : in  std_logic;
        ttc_i             : in  ttc_cmd_t;
        bc0_o             : out std_logic;
        ec0_o             : out std_logic;
        ec0_sync_bc0_o    : out std_logic;
        oc0_o             : out std_logic;
        oc0_sync_bc0_o    : out std_logic;
        resync_o          : out std_logic;
        resync_sync_bc0_o : out std_logic;
        start_o           : out std_logic;
        start_sync_bc0_o  : out std_logic;
        test_en_o         : out std_logic
    );
end bgo_sync;

architecture RTL of bgo_sync is

    signal bc0_in       : std_logic;
    signal bc0_int      : std_logic;
    signal bc0_int1     : std_logic;
    signal ec0_in       : std_logic;
    signal oc0_in       : std_logic;
    signal resync_in    : std_logic;
    signal start_in     : std_logic;
    signal test_en_in   : std_logic;
    signal resync_int   : std_logic;
    signal resync_rqst  : std_logic;
    signal oc0_int      : std_logic;
    signal oc0_rqst     : std_logic;
    signal ec0_int      : std_logic;
    signal ec0_rqst     : std_logic;
    signal start_int    : std_logic;
    signal start_rqst   : std_logic;
    signal test_en_int  : std_logic;
    signal test_en_rqst : std_logic;

begin
                                                        
    bc0_in     <= '1' when ttc_i = TTC_BCMD_BC0         else '0'; -- expected at BX 3540
    ec0_in     <= '1' when ttc_i = TTC_BCMD_EC0         else '0'; -- expected at BX 2000
    oc0_in     <= '1' when ttc_i = TTC_BCMD_OC0         else '0'; -- expected at BX 2000
    resync_in  <= '1' when ttc_i = TTC_BCMD_RESYNC      else '0'; -- expected at BX 2000
    start_in   <= '1' when ttc_i = TTC_BCMD_START       else '0'; -- expected at BX 2000
    test_en_in <= '1' when ttc_i = TTC_BCMD_TEST_ENABLE else '0'; -- expected at BX 3283

    sync_bgos_p : process(clk360)
    begin
        if rising_edge(clk360) then
            if rst360 = '1' then
                bc0_o             <= '0';
                bc0_int           <= '0';
                bc0_int1          <= '0';
                ec0_o             <= '0';
                ec0_int           <= '0';
                ec0_sync_bc0_o    <= '0';
                oc0_o             <= '0';
                oc0_int           <= '0';
                oc0_sync_bc0_o    <= '0';
                resync_o          <= '0';
                resync_int        <= '0';
                resync_sync_bc0_o <= '0';
                start_o           <= '0';
                start_int         <= '0';
                start_sync_bc0_o  <= '0';
                test_en_o         <= '0';
            else
                bc0_o             <= bc0_in;
                bc0_int           <= bc0_in;
                bc0_int1          <= bc0_int;
                ec0_o             <= ec0_in;
                ec0_int           <= ec0_in;
                ec0_sync_bc0_o    <= ec0_rqst and bc0_in;
                oc0_o             <= oc0_in;
                oc0_int           <= oc0_in;
                oc0_sync_bc0_o    <= oc0_rqst and bc0_in;
                resync_o          <= resync_in;
                resync_int        <= resync_in;
                resync_sync_bc0_o <= resync_rqst and bc0_in;
                start_o           <= start_in;
                start_int         <= start_in;
                start_sync_bc0_o  <= start_rqst and bc0_in;
                test_en_o         <= test_en_in;
            end if;
        end if;
    end process;

    resync_rqst_p : process(rst360, resync_int, bc0_int1, bc0_int)
    begin
        if (bc0_int1 = '1' and bc0_int = '0' and resync_int = '0') or rst360 = '1' then
            resync_rqst <= '0';
        elsif (resync_int = '1') then
            resync_rqst <= '1';
        end if;
    end process;

    oc0_rqst_p : process(rst360, oc0_int, bc0_int1, bc0_int)
    begin
        if (bc0_int1 = '1' and bc0_int = '0' and oc0_int = '0') or rst360 = '1' then
            oc0_rqst <= '0';
        elsif (oc0_int = '1') then
            oc0_rqst <= '1';
        end if;
    end process;

    start_rqst_p : process(rst360, start_int, bc0_int1, bc0_int)
    begin
        if (bc0_int1 = '1' and bc0_int = '0' and start_int = '0') or rst360 = '1' then -- bc0 delayd to put start_rqst to '0'
            start_rqst <= '0';
        elsif (start_int = '1') then
            start_rqst <= '1';
        end if;
    end process;

    ec0_rqst_p : process(rst360, ec0_int, bc0_int1, bc0_int)
    begin
        if (bc0_int1 = '1' and bc0_int = '0' and ec0_int = '0') or rst360 = '1' then
            ec0_rqst <= '0';
        elsif (ec0_int = '1') then
            ec0_rqst <= '1';
        end if;
    end process;

end RTL;
