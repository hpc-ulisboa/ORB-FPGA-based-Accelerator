----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 04/26/2024 06:10:32 PM
-- Module Name: brief_binnary_tests - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library intermodules_lib;
use intermodules_lib.intermodules_types.all;


entity brief_binnary_tests is
    Port (
        clk     : in std_logic;
        reset_n : in std_logic;
        pix2compare_1 : in pix2compare_type;
        pix2compare_2 : in pix2compare_type;
        pix2compare_result_r : out std_logic_vector(0 to 6-1) := (others => '0')
    );
end brief_binnary_tests;

architecture rtl of brief_binnary_tests is
    type pix2compare_n_type is array (0 to 6-1) of signed(10 downto 0);
    type pix2compare_result_type is array (0 to 6-1) of signed(10 downto 0);

    signal pix2compare_n : pix2compare_n_type := (others => (others => '0'));
    signal pix2compare_result : pix2compare_result_type := (others => (others => '0'));
    signal pix2compare_result_1bit : std_logic_vector(0 to 6-1) := (others => '0');

begin
    --pix2compare_n(0) <= signed(std_logic_vector'(not ('0'& pix2compare_2(0))&'1'));
    --pix2compare_n(1) <= signed(std_logic_vector'(not ('0'& pix2compare_2(1))&'1'));
    --pix2compare_n(2) <= signed(std_logic_vector'(not ('0'& pix2compare_2(2))&'1'));
    --pix2compare_n(3) <= signed(std_logic_vector'(not ('0'& pix2compare_2(3))&'1'));
    --pix2compare_n(4) <= signed(std_logic_vector'(not ('0'& pix2compare_2(4))&'1'));
    --pix2compare_n(5) <= signed(std_logic_vector'(not ('0'& pix2compare_2(5))&'1'));

    pix2compare_result(0) <= signed(std_logic_vector'("00"& pix2compare_1(0))) - signed(std_logic_vector'("00"&pix2compare_2(0)));
    pix2compare_result(1) <= signed(std_logic_vector'("00"& pix2compare_1(1))) - signed(std_logic_vector'("00"&pix2compare_2(1)));
    pix2compare_result(2) <= signed(std_logic_vector'("00"& pix2compare_1(2))) - signed(std_logic_vector'("00"&pix2compare_2(2)));
    pix2compare_result(3) <= signed(std_logic_vector'("00"& pix2compare_1(3))) - signed(std_logic_vector'("00"&pix2compare_2(3)));
    pix2compare_result(4) <= signed(std_logic_vector'("00"& pix2compare_1(4))) - signed(std_logic_vector'("00"&pix2compare_2(4)));
    pix2compare_result(5) <= signed(std_logic_vector'("00"& pix2compare_1(5))) - signed(std_logic_vector'("00"&pix2compare_2(5)));

    pix2compare_result_1bit(0) <= pix2compare_result(0)(10);
    pix2compare_result_1bit(1) <= pix2compare_result(1)(10);
    pix2compare_result_1bit(2) <= pix2compare_result(2)(10);
    pix2compare_result_1bit(3) <= pix2compare_result(3)(10);
    pix2compare_result_1bit(4) <= pix2compare_result(4)(10);
    pix2compare_result_1bit(5) <= pix2compare_result(5)(10);

    reg_pix2compare_result: process(clk)
    begin
        if (rising_edge(clk)) then
            pix2compare_result_r(0) <= pix2compare_result_1bit(0);
            pix2compare_result_r(1) <= pix2compare_result_1bit(1);
            pix2compare_result_r(2) <= pix2compare_result_1bit(2);
            pix2compare_result_r(3) <= pix2compare_result_1bit(3);
            pix2compare_result_r(4) <= pix2compare_result_1bit(4);
            pix2compare_result_r(5) <= pix2compare_result_1bit(5);
        end if;
    end process reg_pix2compare_result;
end rtl;
