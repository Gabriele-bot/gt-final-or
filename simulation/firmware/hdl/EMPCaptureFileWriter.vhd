--! Using the IEEE Library
library IEEE;
--! Using STD_LOGIC
use IEEE.STD_LOGIC_1164.all;
--! Writing to and from files
use IEEE.STD_LOGIC_TEXTIO.all;
--! Using NUMERIC TYPES
use IEEE.NUMERIC_STD.all;
--! Writing to and from files
use STD.TEXTIO.all;

--! Using the EMP data-types
use work.emp_data_types.all;
use work.emp_project_decl.all;
use work.emp_device_decl.all;
use work.emp_ttc_decl.all;
use work.emp_framework_decl.all;
use work.emp_testbench_helpers.all;
--! Reading and writing emp data to file
use work.emp_data_textio.all;

--! @brief An entity providing a EMPCaptureFileWriter
--! @details Detailed description
entity EMPCaptureFileWriter is
  generic(
    gFileName      :    string;
    gCaptureOffset : in integer := 0;
    gCaptureLength : in integer := 1024;
    gInsertHeader  :    boolean := false;
    gDebugMessages : in boolean := false
    );
  port(
    clk      : in std_logic;
    rst      : in std_logic  := '1';
    pctr     : in pctr_t;
    bctr     : in bctr_t;
    LinkData : in ldata(N_LINKS - 1 downto 0) := (others => LWORD_NULL)
    );
end entity EMPCaptureFileWriter;

--! @brief Architecture definition for entity EMPCaptureFileWriter
--! @details Detailed description
architecture behavioral of EMPCaptureFileWriter is
    
  type CurrentWriteState_t is(Uninitialized, Payload);

-- ----------------------------------------------------------
  function PADDED_INT(VAL : integer; WIDTH : integer) return string is
    variable ret : string(WIDTH downto 1) := (others => '0');
  begin
    if integer'image(VAL) 'length >= WIDTH then
      return integer'image(VAL);
    end if;

    ret(integer'image(VAL) 'length downto 1) := integer'image(VAL);
    return ret;
  end function PADDED_INT;
-- ----------------------------------------------------------



-- ----------------------------------------------------------
  procedure EMPCaptureFileWriterProc(aFileName          : in    string;
                                     file OutFile       :       text;
                                     lCurrentWriteState : inout CurrentWriteState_t;
                                     aFrameCounter      : inout integer;
                                     LinkData           : in    ldata(N_LINKS-1 downto 0);
                                     IsHeader           :       std_logic_vector(N_LINKS-1 downto 0);
                                     aDebugMessages     : in    boolean := false
                                     ) is
    variable L, DEBUG : line;
  begin
    if lCurrentWriteState = Uninitialized then
-- Debug
      if aDebugMessages then
        WRITE(DEBUG, string' ("UNINITIALIZED : "));
        WRITE(DEBUG, aFrameCounter);
        WRITELINE(OUTPUT, DEBUG);
      end if;
-- Open File
      FILE_OPEN(OutFile, aFileName, write_mode);

      WRITE(L, string' ("ID: ALGO_TESTBENCH"));
      WRITELINE(OutFile, L);

      WRITE(L, string' ("Metadata: (strobe,) start of orbit, start of packet, end of packet, valid"));
      WRITELINE(OutFile, L);

      WRITE(L, string' (""));
      WRITELINE(OutFile, L);

      WRITE(L, string' ("      Link  "));
      for q in 0 to N_REGION-1 loop
        if REGION_CONF(q).buf_o_kind /= no_buf then
          for c in 0 to 3 loop
            WRITE(L, string' ("            "));
            WRITE(L, PADDED_INT(q*4+c, 3));
            WRITE(L, string' ("        "));
          end loop;
        end if;
      end loop;
      WRITELINE(OutFile, L);

      lCurrentWriteState := Payload;
    end if;

    if aDebugMessages then
      WRITE(DEBUG, string' ("CAPTURING FRAME "));
      WRITE(DEBUG, aFrameCounter);
      WRITELINE(OUTPUT, DEBUG);
    end if;

    WRITE(L, string' ("Frame "));
    WRITE(L, PADDED_INT(aFrameCounter, 4));
    WRITE(L, string' ("  "));

    for q in 0 to N_REGION-1 loop
      if REGION_CONF(q).buf_o_kind /= no_buf then
        for c in 0 to 3 loop
          if REGION_CONF(q).buf_o_kind /= no_buf then
            if IsHeader(q*4+c) /= '0' then
              WRITE(L, string' (" 0001 00001000"));
            else
              WRITE(L, string' ("  "));
              WRITE(L, LinkData(q*4+c));
            end if;
          end if;
        end loop;
      end if;
    end loop;

    WRITELINE(OutFile, L);

  end procedure EMPCaptureFileWriterProc;
-- ----------------------------------------------------------

begin
  process(clk)
    file OutFile                : text;
    variable lCurrentWriteState : CurrentWriteState_t                  := Uninitialized;
    variable lClkCount          : integer                              := -1;
    variable lFrame             : integer                              := 0;
    variable LinkData_d         : ldata(N_LINKS-1 downto 0)            := (others => LWORD_NULL);
    variable IsHeader           : std_logic_vector(N_LINKS-1 downto 0) := (others => '0');
  begin
    
    if rising_edge(clk) then
        
      lFrame := lClkCount-gCaptureOffset;
      if (lFrame >= 0 and lFrame < gCaptureLength) then
        if ( gInsertHeader ) then
          for q IN 0 to N_LINKS-1 loop
            IsHeader( q ) := LinkData( q ) .valid and not LinkData_d( q ) .valid;
          end loop;
        end if;
        EMPCaptureFileWriterProc(gFileName, OutFile, lCurrentWriteState, lFrame, LinkData_d, IsHeader, gDebugMessages);
        lFrame   := lFrame + 1;
      end if;

      LinkData_d := LinkData;

      -- TODO Do we want to write (or overwrite) the outputs at each orbit?
      -- for now I just commented the line
      --if (rst = '1') or (pctr = "1000" and bctr = std_logic_vector(to_unsigned(LHC_BUNCH_COUNT-1, bctr'length))) then
      if (rst = '0') then  
        lClkCount := lClkCount + 1;
      else
        lClkCount := -1;
      end if;

    end if;
  end process;
end architecture behavioral;
