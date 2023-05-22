library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library xpm;
use xpm.vcomponents.all;

entity SDPRAM_wrapper is
    generic(
        ADDR_WIDTH : integer;
        DATA_WIDTH : integer;
        STYLE      : string := "auto"
    );
    port(
        clk   : in  std_logic;
        rst   : in  std_logic;
        ena   : in  std_logic;
        wea   : in  std_logic;
        addra : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
        din   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        enb   : in  std_logic;
        addrb : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
        dout  : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity SDPRAM_wrapper;

architecture RTL of SDPRAM_wrapper is

begin

    xpm_memory_sdpram_inst : xpm_memory_sdpram
        generic map(
            ADDR_WIDTH_A            => ADDR_WIDTH,
            ADDR_WIDTH_B            => ADDR_WIDTH,
            AUTO_SLEEP_TIME         => 0,
            BYTE_WRITE_WIDTH_A      => DATA_WIDTH,
            CASCADE_HEIGHT          => 0,
            CLOCKING_MODE           => "common_clock",
            ECC_MODE                => "no_ecc",
            MEMORY_INIT_FILE        => "none",
            MEMORY_INIT_PARAM       => "0",
            MEMORY_OPTIMIZATION     => "true",
            MEMORY_PRIMITIVE        => STYLE,
            MEMORY_SIZE             => 2 ** (ADDR_WIDTH) * DATA_WIDTH,
            MESSAGE_CONTROL         => 0,
            READ_DATA_WIDTH_B       => DATA_WIDTH,
            READ_LATENCY_B          => 1,
            READ_RESET_VALUE_B      => "0",
            RST_MODE_A              => "SYNC",
            RST_MODE_B              => "SYNC",
            SIM_ASSERT_CHK          => 0,
            USE_EMBEDDED_CONSTRAINT => 0,
            USE_MEM_INIT            => 1,
            USE_MEM_INIT_MMI        => 0,
            WAKEUP_TIME             => "disable_sleep",
            WRITE_DATA_WIDTH_A      => DATA_WIDTH,
            WRITE_MODE_B            => "read_first",
            WRITE_PROTECT           => 1
        )
        port map(
            dbiterrb       => open,
            doutb          => dout,
            sbiterrb       => open,
            addra          => addra,
            addrb          => addrb,
            clka           => clk,
            clkb           => clk,
            dina           => din,
            ena            => ena,
            enb            => enb,
            injectdbiterra => '0',
            injectsbiterra => '0',
            regceb         => '1',
            rstb           => rst,
            sleep          => '0',
            wea(0)         => wea
        );


end architecture RTL;
