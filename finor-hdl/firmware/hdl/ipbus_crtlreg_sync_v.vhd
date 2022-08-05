library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;

library xpm;
use xpm.vcomponents.all;

entity ipbus_crtlreg_sync_v is
    generic(
        N_CTRL     : natural := 1;
        N_STAT     : natural := 1;
        FF_STAGES  : natural := 3;
        SWAP_ORDER : boolean := false
    );
    port(
        clk: in std_logic;
        rst: in std_logic;
        ipb_in: in ipb_wbus;
        ipb_out: out ipb_rbus;
        slv_clk: in std_logic;
        d: in ipb_reg_v(N_STAT - 1 downto 0) := (others => (others => '0'));
        q: out ipb_reg_v(N_CTRL - 1 downto 0);
        qmask: in ipb_reg_v(N_CTRL - 1 downto 0) := (others => (others => '1'));
        stb: out std_logic_vector(N_CTRL - 1 downto 0)
    );
end entity ipbus_crtlreg_sync_v;

architecture RTL of ipbus_crtlreg_sync_v is
    
    signal d_slv   : ipb_reg_v(N_STAT - 1 downto 0);
    signal q_slv   : ipb_reg_v(N_CTRL - 1 downto 0);
    signal stb_slv : std_logic_vector(N_CTRL - 1 downto 0); 
    
    signal d_ipbus : ipb_reg_v(N_STAT - 1 downto 0);
    signal q_ipbus : ipb_reg_v(N_CTRL - 1 downto 0);
    signal stb_ipbus : std_logic_vector(N_CTRL - 1 downto 0); 

begin
    
    d_slv <= d;
    q     <= q_slv;
    stb   <= stb_slv;
    
    
    stat_sync_l : for i in 0 to N_STAT - 1 generate
    
        xpm_cdc_array_single_inst : xpm_cdc_array_single
            generic map (
            DEST_SYNC_FF   => FF_STAGES, -- DECIMAL; range: 2-10
            INIT_SYNC_FF   => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            SRC_INPUT_REG  => 1, -- DECIMAL; 0=do not register input, 1=register input
            WIDTH          => 32 -- DECIMAL; range: 1-1024
            )
            port map (
            dest_out => d_ipbus(i), -- WIDTH-bit output: src_in synchronized to the destination clock domain. This
            -- output is registered.
            dest_clk => clk, -- 1-bit input: Clock signal for the destination clock domain.
            src_clk  => slv_clk, -- 1-bit input: optional; required when SRC_INPUT_REG = 1
            src_in   => d_slv(i) -- WIDTH-bit input: Input single-bit array to be synchronized to destination clock
            -- domain. It is assumed that each bit of the array is unrelated to the others.
            -- This is reflected in the constraints applied to this macro. To transfer a binary
            -- value losslessly across the two clock domains, use the XPM_CDC_GRAY macro
            -- instead.
            );
                
    end generate;
    
    ctrl_sync_l : for i in 0 to N_CTRL - 1 generate
    
        xpm_cdc_array_single_inst : xpm_cdc_array_single
            generic map (
            DEST_SYNC_FF   => FF_STAGES, -- DECIMAL; range: 2-10
            INIT_SYNC_FF   => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            SRC_INPUT_REG  => 1, -- DECIMAL; 0=do not register input, 1=register input
            WIDTH          => 33 -- DECIMAL; range: 1-1024
            )
            port map (
            dest_out(31 downto 0) => q_slv(i), -- WIDTH-bit output: src_in synchronized to the destination clock domain. This
            dest_out(32)          => stb_slv(i),
            -- output is registered.
            dest_clk => slv_clk, -- 1-bit input: Clock signal for the destination clock domain.
            src_clk  => clk, -- 1-bit input: optional; required when SRC_INPUT_REG = 1
            src_in(31 downto 0)   => q_ipbus(i), -- WIDTH-bit input: Input single-bit array to be synchronized to destination clock
            src_in(32)            => stb_ipbus(i)
            -- domain. It is assumed that each bit of the array is unrelated to the others.
            -- This is reflected in the constraints applied to this macro. To transfer a binary
            -- value losslessly across the two clock domains, use the XPM_CDC_GRAY macro
            -- instead.
            );
                
    end generate;
    
    
    
    ipbus_crtlreg_v_i : entity work.ipbus_ctrlreg_v
        generic map(
            N_CTRL     => N_CTRL,
            N_STAT     => N_STAT,
            SWAP_ORDER => SWAP_ORDER
        )
        port map(
            clk         => clk,
            reset       => rst,
            ipbus_in    => ipb_in,
            ipbus_out   => ipb_out,
            d           => d_ipbus,    
            q           => q_ipbus,
            qmask       => qmask,
            stb         => stb_ipbus
        );
        
        
    
    

end architecture RTL;

