----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 10/01/2024 07:33:42 PM
-- Module Name: bram_tdp_vhd - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity bram_tdp_vhd is
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
end bram_tdp_vhd;

architecture rtl of bram_tdp_vhd is
component rams_tdp_rf_rf
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
    end component;
begin
bram_instance_1: rams_tdp_rf_rf
        generic map (
            WIDTH_G   => WIDTH_G  ,
            SIZE      => SIZE     ,
            ADDRWIDTH => ADDRWIDTH,
            INIT_FILE => INIT_FILE
        )
        port map (
            clkA => clkA ,
            clkB => clkB ,
            enA  => enA  ,
            enB  => enB  ,
            weA  => weA  ,
            weB  => weB  ,
            addrA=> addrA,
            addrB=> addrB,
            diA  => diA  ,
            diB  => diB  ,
            doA  => doA  ,
            doB  => doB  
        );

end rtl;
