----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 05/10/2024 01:39:42 PM
-- Module Name: rgb2bw - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity rgb2bw is
    Port (
        clk : in std_logic;
        rgb : in std_logic_vector (23 downto 0);
        valid_pix : in std_logic;
        bw : out std_logic_vector (7 downto 0);
        valid_bw : out std_logic
    );
end rgb2bw;

architecture rtl of rgb2bw is
    signal red, green, blue : unsigned(7 downto 0);
    signal red_step_1 : unsigned(10 downto 0);
    signal red_step_2 : unsigned(12 downto 0);
    signal red_step_3 : unsigned(13 downto 0);
    signal green_step_1 : unsigned(12 downto 0);
    signal green_step_2 : unsigned(12 downto 0);
    signal green_step_3 : unsigned(15 downto 0);
    signal blue_step_1_1 : unsigned(13 downto 0);
    signal blue_step_1_2 : unsigned(13 downto 0);
    signal blue_step_2 : unsigned(16 downto 0);
    signal bw_red, bw_green, bw_blue : unsigned(8 downto 0);
    signal s_bw : unsigned(8 downto 0);
begin
    red <= unsigned(rgb(23 downto 16));
    blue <= unsigned(rgb(15 downto 8));
    green <= unsigned(rgb(7 downto 0));

    red_step_1 <= unsigned(std_logic_vector'(std_logic_vector(red)&"000"))-red;
    red_step_2 <= unsigned(std_logic_vector'(std_logic_vector(red_step_1)&"00"))-red;
    red_step_3 <= unsigned(std_logic_vector'(std_logic_vector(red_step_2)&"0"));
    bw_red <= unsigned(std_logic_vector'(std_logic_vector("000"&red_step_3(13 downto 8))));

    green_step_1 <= unsigned(std_logic_vector'(std_logic_vector(green)&"00000")) - green;
    green_step_2 <= green_step_1 - unsigned(std_logic_vector'("00"&std_logic_vector(green)&"000"));
    green_step_3 <= unsigned(std_logic_vector'(std_logic_vector(green_step_2)&"000"));
    bw_green <= unsigned(std_logic_vector'(std_logic_vector("0"&green_step_3(15 downto 8))));

    blue_step_1_1 <= unsigned(std_logic_vector'("00"&std_logic_vector(blue)&"0000")) - blue;
    blue_step_1_2 <= unsigned(std_logic_vector'(std_logic_vector(blue)&"000000")) - blue;
    blue_step_2 <= unsigned(std_logic_vector'(std_logic_vector(blue_step_1_1)&"000")) + blue_step_1_2;
    bw_blue <= unsigned(blue_step_2(16 downto 8));

    s_bw <= bw_red + bw_green + bw_blue;

    process(clk)
    begin
        if rising_edge(clk) then
            bw <= std_logic_vector(s_bw(7 downto 0));
            valid_bw <= valid_pix;
        end if;
    end process;
end rtl;
