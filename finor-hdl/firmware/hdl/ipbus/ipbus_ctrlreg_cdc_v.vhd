
-- ipbus_ctrlreg_cdc_v
--
-- Generic control / status register bank with CDC
--
-- Provides N_CTRL control registers (32b each), rw
-- Provides N_STAT status registers (32b each), ro
--
-- Address space needed is twice that needed by the largest block of registers, unless
-- one of N_CTRL or N_STAT is zero.
--
-- By default, bottom part of read address space is control, top is status.
-- Set SWAP_ORDER to reverse this.
--
-- Same structure as ipbus_ctrlreg_v with the addition of a CDC xmp to handle the crossing
--
-- Gabriele Bortolato 2023

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ipbus.all;
use work.ipbus_reg_types.all;

library xpm;
use xpm.vcomponents.all;

entity ipbus_ctrlreg_cdc_v is
    generic(
        N_CTRL         : natural := 1;
        N_STAT         : natural := 1;
        SWAP_ORDER     : boolean := FALSE;
        DEST_SYNC_FF   : natural := 2;
        INIT_SYNC_FF   : natural := 0;
        SIM_ASSERT_CHK : natural := 0;
        SRC_INPUT_REG  : natural := 1
    );
    port(
        clk     : in  std_logic;
        rst     : in  std_logic;
        ipb_in  : in  ipb_wbus;
        ipb_out : out ipb_rbus;
        slv_clk : in  std_logic;
        d       : in  ipb_reg_v(N_STAT - 1 downto 0) := (others => (others => '0'));
        q       : out ipb_reg_v(N_CTRL - 1 downto 0);
        qmask   : in  ipb_reg_v(N_CTRL - 1 downto 0) := (others => (others => '1'));
        stb     : out std_logic_vector(N_CTRL - 1 downto 0)
    );
end entity ipbus_ctrlreg_cdc_v;

architecture RTL of ipbus_ctrlreg_cdc_v is
    
    signal d_ipbus     : ipb_reg_v(N_STAT - 1 downto 0) := (others => (others => '0'));
    signal q_ipbus     : ipb_reg_v(N_CTRL - 1 downto 0);
    signal qmask_ipbus : ipb_reg_v(N_CTRL - 1 downto 0) := (others => (others => '1'));
    signal stb_ipbus   : std_logic_vector(N_CTRL - 1 downto 0);
    
begin

    ctrlreg_i : entity work.ipbus_ctrlreg_v
        generic map(
            N_CTRL     => N_CTRL,
            N_STAT     => N_STAT,
            SWAP_ORDER => SWAP_ORDER
        )
        port map(
            clk       => clk,
            reset     => rst,
            ipbus_in  => ipb_in,
            ipbus_out => ipb_out,
            d         => d_ipbus,
            q         => q_ipbus,
            qmask     => qmask_ipbus,
            stb       => stb_ipbus
        );

    gen_STAT_l : for i in 0 to N_STAT - 1 generate
        xpm_cdc_input_i : xpm_cdc_array_single
            generic map (
                DEST_SYNC_FF   => DEST_SYNC_FF,
                INIT_SYNC_FF   => INIT_SYNC_FF,
                SIM_ASSERT_CHK => SIM_ASSERT_CHK,
                SRC_INPUT_REG  => SRC_INPUT_REG,
                WIDTH          => 32
            )
            port map (
                dest_out => d_ipbus(i),
                dest_clk => clk,
                src_clk  => slv_clk,
                src_in   => d(i)
            );
    end generate;

    gen_CRTL_l : for i in 0 to N_CTRL - 1 generate
        xpm_cdc_output_i : xpm_cdc_array_single
            generic map (
                DEST_SYNC_FF   => DEST_SYNC_FF,
                INIT_SYNC_FF   => INIT_SYNC_FF,
                SIM_ASSERT_CHK => SIM_ASSERT_CHK,
                SRC_INPUT_REG  => SRC_INPUT_REG,
                WIDTH          => 32
            )
            port map (
                dest_out => q(i),
                dest_clk => slv_clk,
                src_clk  => clk,
                src_in   => q_ipbus(i)
            );
            
            xpm_cdc_qmask_i : xpm_cdc_array_single
            generic map (
                DEST_SYNC_FF   => DEST_SYNC_FF,
                INIT_SYNC_FF   => INIT_SYNC_FF,
                SIM_ASSERT_CHK => SIM_ASSERT_CHK,
                SRC_INPUT_REG  => SRC_INPUT_REG,
                WIDTH          => 32
            )
            port map (
                dest_out => qmask_ipbus(i),
                dest_clk => clk,
                src_clk  => slv_clk,
                src_in   => qmask(i)
            );
            
            xpm_cdc_stb_i : xpm_cdc_single
            generic map (
                DEST_SYNC_FF   => DEST_SYNC_FF,
                INIT_SYNC_FF   => INIT_SYNC_FF,
                SIM_ASSERT_CHK => SIM_ASSERT_CHK,
                SRC_INPUT_REG  => SRC_INPUT_REG
            )
            port map (
                dest_out => stb(i),
                dest_clk => slv_clk,
                src_clk  => clk,
                src_in   => stb_ipbus(i)
            );
    end generate;

end architecture RTL;
