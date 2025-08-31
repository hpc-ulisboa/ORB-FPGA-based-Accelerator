----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 04/26/2024 06:10:32 PM
-- Module Name: constructor_supervisor - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity constructor_supervisor is
    generic (
        ORIENTATION_LINE_SIZE : natural := 37
    );
    Port (
        clk     : in std_logic;
        reset_n : in std_logic;
        brief_set_bitmask : inout std_logic_vector(255 downto 0);
        descriptor_internal_r : in std_logic_vector(255 downto 0);
        accept_pix : inout std_logic;
        descriptor : out std_logic_vector(255 downto 0);
        constructor_ready : out std_logic;
        start_constr : in std_logic;
        constructor_finished : inout std_logic;
        pixel_toggle : out std_logic;
        descriptor_ready : out std_logic
    );
end constructor_supervisor;

architecture rtl of constructor_supervisor is
    constant brief_num_sections : natural := 46;
    constant brief_section_size : natural := 6;
    constant pix2orientation_delay : natural := 13;
    constant constructor_delay : natural := brief_num_sections*2+5;

    signal descriptor_internal : std_logic_vector(255 downto 0) := (others => '0');
    signal constr_counter : natural := 1;
    signal brief_section_cntr : integer := 0;
    signal constructor_ready_s : std_logic := '0';
    signal wb_counter : natural := 0;

    signal pixel_toggle_s : std_logic := '0';

begin
    constructor_supervisor: process(clk)
    begin
        if (rising_edge(clk)) then
            if (accept_pix = '1') then
                wb_counter <= wb_counter + 1;
            else
                wb_counter <= 1;
            end if;
            if ((wb_counter >= ORIENTATION_LINE_SIZE+pix2orientation_delay-1) and (accept_pix = '1') and (start_constr = '0')) then
                constructor_ready_s <= '1';
                constructor_ready <= '1';
            else
                constructor_ready_s <= '0';
                constructor_ready <= '0';
            end if;
            if (constr_counter = constructor_delay and constructor_finished = '0') then
                descriptor_ready <= '1';
            else
                descriptor_ready <= '0';
            end if;
            if (constructor_finished = '1') then
                pixel_toggle <= '0';
                pixel_toggle_s <= '0';
                if (start_constr = '1') then
                    accept_pix <= '0';
                    constr_counter <= 1;
                    constructor_finished <= '0';
                    brief_section_cntr <= 0;
                    -- The bitmask is set such that when the first section is ready the bitmask is x"...0003F"
                    brief_set_bitmask <= x"000FC00000000000000000000000000000000000000000000000000000000000";
                else 
                    accept_pix <= '1';
                    constr_counter <= constr_counter + 1;
                    if (brief_section_cntr < brief_num_sections) then
                        brief_section_cntr <= brief_section_cntr + 1;
                    end if;
                    if (brief_section_cntr < brief_num_sections and (pixel_toggle_s = '0')) then
                        brief_set_bitmask <= std_logic_vector'(brief_set_bitmask rol brief_section_size);
                    elsif (brief_section_cntr = brief_num_sections) then
                        brief_set_bitmask <= std_logic_vector'(brief_set_bitmask sll brief_section_size);
                    end if;
                    constructor_finished <= constructor_finished;
                end if;
                if (constr_counter > constructor_delay+3) then
                    descriptor <= (others => '0');
                end if;
            else
                pixel_toggle <= not pixel_toggle_s;
                pixel_toggle_s <= not pixel_toggle_s;
                if (constr_counter < constructor_delay) then
                    constructor_finished <= '0';
                    descriptor <= (others => '0');
                elsif (constr_counter = constructor_delay) then
                    constructor_finished <= '1';
                    descriptor <= descriptor_internal_r;
                end if;
                constr_counter <= constr_counter + 1;
                if ((brief_section_cntr < brief_num_sections) and (pixel_toggle_s = '1')) then
                    brief_section_cntr <= brief_section_cntr + 1;
                end if;
                if ((brief_section_cntr < brief_num_sections) and (pixel_toggle_s = '1')) then
                    brief_set_bitmask <= std_logic_vector'(brief_set_bitmask rol brief_section_size);
                elsif (brief_section_cntr = brief_num_sections) then
                    brief_set_bitmask <= std_logic_vector'(brief_set_bitmask sll brief_section_size);
                end if;
                accept_pix <= accept_pix;
            end if;
        end if;
    end process constructor_supervisor;
end rtl;
