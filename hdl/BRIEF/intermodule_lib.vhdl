----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 04/17/2024 02:53:21 PM
-- Module Name: intermodules_types - Library
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library intermodules_lib;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


package intermodules_types is
    type pix_array_t is array (37-1 downto 0) of std_logic_vector(8-1 downto 0);
    type pix2compare_type is array (0 to 6-1) of std_logic_vector(8 downto 0);
end package intermodules_types;
