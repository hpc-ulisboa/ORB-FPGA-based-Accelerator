----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 04/26/2024 06:10:32 PM
-- Module Name: compose_brief - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity compose_brief is
    Port (
        clk     : in std_logic;
        reset_n : in std_logic;
        brief_set_bitmask : in std_logic_vector(255 downto 0);
        pix2compare_result_r : in std_logic_vector(0 to 5);
        descriptor_internal_r : inout std_logic_vector(255 downto 0)
    );
end compose_brief;

architecture rtl of compose_brief is
    constant brief_num_sections : natural := 43;
    constant last_section_i : natural := brief_num_sections-1;
    constant brief_section_size : natural := 6;

    signal descriptor_internal : std_logic_vector(255 downto 0) := (others => '0');

begin

    spread_results: for i in 0 to brief_num_sections-2 generate
        spred_section: for j in 0 to brief_section_size-1 generate
            descriptor_internal(i*brief_section_size+j) <= reset_n and ((descriptor_internal_r(i*brief_section_size+j) and not(brief_set_bitmask(i*brief_section_size+j))) or (pix2compare_result_r(j) and brief_set_bitmask(i*brief_section_size+j)));
        end generate spred_section;
    end generate spread_results;
    -- The last section has only 4 bits and not the full 6 so it needs to be described separetly
    spred_final_section: for j in 0 to 4-1 generate
        descriptor_internal(last_section_i*brief_section_size+j) <= reset_n and ((descriptor_internal_r(last_section_i*brief_section_size+j) and not(brief_set_bitmask(last_section_i*brief_section_size+j))) or (pix2compare_result_r(j) and brief_set_bitmask(last_section_i*brief_section_size+j)));
    end generate spred_final_section;

    reg_descriptor: process(clk)
    begin
        if(rising_edge(clk)) then
            for i in 0 to descriptor_internal_r'high loop
                descriptor_internal_r(i) <= descriptor_internal(i);
            end loop;
        end if;
    end process reg_descriptor;
end rtl;
