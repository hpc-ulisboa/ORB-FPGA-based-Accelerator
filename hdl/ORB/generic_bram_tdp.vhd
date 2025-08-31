-- Dual-Port Block RAM with Two Write Ports
-- Correct Modelization with a Shared Variable
-- File: generic_bram_tdp.vhd

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
use std.textio.all;

entity generic_bram_tdp is
    generic(
        WIDTH_G : integer := 32;
        SIZE : integer := 64;
        ADDRWIDTH : integer := 6;
        INIT_FILE : string := "NONE"
    );
    port(
        clkA : in std_logic;
        clkB : in std_logic;
        enA : in std_logic;
        enB : in std_logic;
        weA : in std_logic;
        weB : in std_logic;
        addrA : in std_logic_vector(ADDRWIDTH - 1 downto 0);
        addrB : in std_logic_vector(ADDRWIDTH - 1 downto 0);
        diA : in std_logic_vector(WIDTH_G - 1 downto 0);
        diB : in std_logic_vector(WIDTH_G - 1 downto 0);
        doA : out std_logic_vector(WIDTH_G - 1 downto 0);
        doB : out std_logic_vector(WIDTH_G - 1 downto 0)
    );
end generic_bram_tdp;

architecture syn of generic_bram_tdp is
 type ram_type is array (0 to SIZE - 1) of std_logic_vector(WIDTH_G-1 downto 0);
 impure function InitRamFromFile(RamFileName : in string) return ram_type is
     variable RAM : ram_type := (others => (others => '0'));
     variable RamFileLine : line;
     variable RamLineBits : bit_vector(0 to WIDTH_G - 1);
     FILE RamFile : text;
     variable openStatus : FILE_OPEN_STATUS;
 begin
     if RamFileName = "NONE" then
         return RAM;
     else
         file_open(openStatus, RamFile, RamFileName, READ_MODE);
         if openStatus /= open_ok then
             report "Error opening file " & RamFileName severity failure;
             return RAM;
         end if;
 
         for I in ram_type'range loop
             readline(RamFile, RamFileLine);
             read(RamFileLine, RamLineBits);
             RAM(I) := to_stdlogicvector(RamLineBits);
         end loop;
 
         file_close(RamFile); -- Close the file after reading
         return RAM;
     end if;
 end function;
 shared variable RAM : ram_type := InitRamFromFile(INIT_FILE);
begin
 process(CLKA)
 begin
  if CLKA'event and CLKA = '1' then
   if ENA = '1' then
    DOA <= RAM(to_integer(unsigned(ADDRA)));
    if WEA = '1' then
     RAM(to_integer(unsigned(ADDRA))) := DIA;
    end if;
   end if;
  end if;
 end process;

 process(CLKB)
 begin
  if CLKB'event and CLKB = '1' then
   if ENB = '1' then
    DOB <= RAM(to_integer(unsigned(ADDRB)));
    if WEB = '1' then
     RAM(to_integer(unsigned(ADDRB))) := DIB;
    end if;
   end if;
  end if;
 end process;

end syn;
