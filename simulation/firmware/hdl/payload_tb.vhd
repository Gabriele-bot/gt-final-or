library std;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.tb_helpers.all;
use STD.TEXTIO.all;
use ieee.std_logic_textio.all;

use work.ipbus.all;
use work.emp_data_types.all;
use work.emp_project_decl.all;

use work.emp_device_decl.all;
use work.emp_ttc_decl.all;

use work.common_pkg.all;

entity testbench is
end testbench;

architecture behavior of testbench is

  constant verbose : boolean := true;

  constant div480          : integer   := ALGO_FREQ/2;
  constant div360          : integer   := 180;
  constant div40           : integer   := 20;
  constant half_period_480 : time      := 250000 ps / div480;
  constant half_period_360 : time      := half_period_480 * 4/3;
  constant half_period_40  : time      := half_period_480 * 12;
  constant n_links         : integer   := 4 * N_REGION;
  signal   clk480          : std_logic := '1';
  signal   clk360          : std_logic := '1';
  signal   clk40           : std_logic := '1';
  signal   clk_payload     : std_logic_vector(2 downto 0);
  signal   rst_payload     : std_logic_vector(2 downto 0);
  signal   rst             : std_logic_vector(N_REGION - 1 downto 0) := (others => '0');

  signal iD : ldata(n_links - 1 downto 0);
  signal oQ : ldata(n_links - 1 downto 0);

begin

  uut : entity work.emp_payload
    port map (
      clk               => clk480, -- ipbus signals
      rst               => rst(0),
      ipb_in.ipb_addr   => (others => '0'),
      ipb_in.ipb_wdata  => (others => '0'),
      ipb_in.ipb_strobe => '0',
      ipb_in.ipb_write  => '0',
      ipb_out           => open,
      clk_payload       => clk_payload,
      rst_payload       => rst_payload,
      clk_p             => clk360, -- data clock
      rst_loc           => rst,
      clken_loc         => (others => '1'),
      ctrs              => (others => ("00000000", '0', "000000000000", "0000")), -- missing!
      bc0               => open,
      d                 => iD, -- data in
      q                 => oQ, -- data out
      gpio              => open, -- IO to mezzanine connector
      gpio_en           => open -- IO to mezzanine connector (three-state enables)
      );
  -- Clocks
  clk480         <= not clk480 after half_period_480;
  clk360         <= not clk360 after half_period_360;
  clk40          <= not clk40  after half_period_40;
  clk_payload(ALGO_CLK) <= clk480;
  clk_payload(LHC_CLK)  <= clk40;

  tb : process
    file F                      : text open read_mode is "inputPattern.txt";
    file FI                     : text open write_mode is "payload_tb.inputs";
    file FO                     : text open write_mode is "payload_tb.results";
    variable L, QL, LL          : line;
    constant TM_PERIOD          : integer := 5;
    constant DEMUX_LATENCY_VU9P     : integer := 9*TM_PERIOD*TM_PERIOD; -- Time to get the data in etc.
    variable NEXT_TM_SLICE      : natural := 1;
    variable ACTIVE_TM_SLICES   : std_logic_vector(TM_PERIOD-1 downto 0) := (others => '0');
    type counters_t is array (natural range <>) of natural;
    variable TM_SLICES_CNT      : counters_t(TM_PERIOD-1 downto 0) := (81, 63, 45, 27 ,9);
    variable frames             : ldata(n_links - 1 downto 0);
    variable iFrame             : integer := 0;
    variable validFrame         : boolean;
    -- variable remainingEvents    : integer := 2;
    variable remainingEvents    : integer := 2*DEMUX_LATENCY_VU9P;
    variable outFrames          : ldata(n_links - 1 downto 0);

  begin  -- process tb
    -- Write header
    WriteHeader(n_links, FI);
    WriteHeader(n_links, FO);

    frames := (others => ("0000000000000000000000000000000000000000000000000000000000000000", '0', '0', '0'));
    iD <= frames;
    rst         <= (others => '1');
    rst_payload <= (others => '1');
    -- wait for 3*half_period_40;
    wait for 234*half_period_360;  -- Enough for valid data to reach outputs
    rst         <= (others => '0');
    rst_payload <= (others => '0');
    -- wait for 2*half_period_40;  -- wait until global set/reset completes
    -- TODO: Should adjust the delays below when we know at which point Serenity sends out the data. (Might not be very important though, let's see.)
    wait for 32*half_period_360;  -- wait until global set/reset completes
    frames := (others => ("0000000000000000000000000000000000000000000000000000000000000000", '0', '0', '0'));
    iD <= frames;
    wait for 2*half_period_360;
    frames := (others => ("0000000000000000000000000000000000000000000000000000000000000000", '0', '0', '0'));
    iD <= frames;
    wait for 2*half_period_360;
    -- TODO: I seem to have two 360 half periods mysteriously show up around here. Should find out where they came from...

    while remainingEvents > 0 loop
      if not endfile(F) then
        ReadInFrames(F, validFrame, frames);
      else
         -- frames := (others => (std_logic_vector(to_unsigned(remainingEvents, 16)) & std_logic_vector(to_unsigned(remainingEvents, 16)) & std_logic_vector(to_unsigned(remainingEvents, 16))& std_logic_vector(to_unsigned(remainingEvents, 16)), '1', '1', '1'));
        frames := (others => ("0000000000000000000000000000000000000000000000000000000000000000", '0', '1', '0'));
        remainingEvents := remainingEvents-1;
      end if;

      -- Filling payload
      iD <= frames;

      if validFrame or endfile(F) then  -- We should only advance time if there was valid data in the frame (or we're done).
          wait for 2*half_period_360;
      end if;

      outFrames := oQ;

      DumpFrames(outFrames, iFrame, FO);
      DumpFrames(frames, iFrame, FI);

      iFrame := iFrame+1;
    end loop;
    finish(0);
  end process tb;

end;