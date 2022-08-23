library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use work.ipbus.all;

use work.ipbus_decode_ipbus_dpram_4096x576.all;

entity ipbus_dpram_4096x576 is
    generic(
        INIT_VALUE : std_logic_vector(575 downto 0) := (others => '0');
        DATA_WIDTH : positive := 576
    );
    port
(
        clk     : in  std_logic;
        rst     : in  std_logic;
        ipb_in  : in  ipb_wbus;
        ipb_out : out ipb_rbus;
        rclk    : in  std_logic;
        we      : in  std_logic := '0';
        d       : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        q       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        addr    : in  std_logic_vector(11  downto 0)
    );

end ipbus_dpram_4096x576;

architecture rtl of ipbus_dpram_4096x576 is

    type mem_index_array is array (0 to 17) of natural;
    constant mem_index : mem_index_array :=
 (N_SLV_DATA_0_31   , N_SLV_DATA_32_63  , N_SLV_DATA_64_95  ,
                                             N_SLV_DATA_96_127 , N_SLV_DATA_128_159, N_SLV_DATA_160_191,
                                             N_SLV_DATA_192_223, N_SLV_DATA_224_255, N_SLV_DATA_256_287,
                                             N_SLV_DATA_288_319, N_SLV_DATA_320_351, N_SLV_DATA_352_383,
                                             N_SLV_DATA_384_415, N_SLV_DATA_416_447, N_SLV_DATA_448_479,
                                             N_SLV_DATA_480_511, N_SLV_DATA_512_543, N_SLV_DATA_544_575
                                            );

    -- fabric signals        
    signal ipb_to_slaves  : ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);

begin

    fabric_i: entity work.ipbus_fabric_sel
        generic map(
            NSLV      => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH
        )
        port map(
            ipb_in          => ipb_in,
            ipb_out         => ipb_out,
            sel             => ipbus_sel_ipbus_dpram_4096x576(ipb_in.ipb_addr),
            ipb_to_slaves   => ipb_to_slaves,
            ipb_from_slaves => ipb_from_slaves
        );

    gen_ipbus_dpram_l : for i in 0 to 17 generate

        ipbus_dpram_i: entity work.ipbus_initialized_dpram
            generic map(
                INIT_VALUE => INIT_VALUE(32*(i+1)-1 downto 32*i),
                ADDR_WIDTH => 12,
                DATA_WIDTH => 32
            )
            port map(
                clk     => clk,
                rst     => rst,
                ipb_in  => ipb_to_slaves  (mem_index(i)),
                ipb_out => ipb_from_slaves(mem_index(i)),
                rclk    => rclk,
                we      => we,
                d       => d(32*(i+1)-1 downto 32*i),
                q       => q(32*(i+1)-1 downto 32*i),
                addr    => std_logic_vector(addr)
            );

    end generate;


end rtl;