----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 05/10/2024 02:24:17 PM
-- Module Name: frame_supervisor - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity frame_supervisor is
    Port ( 
        clk         : in std_logic;
        rst         : in std_logic;
        v_sync      : in std_logic;
        valid_pix   : in std_logic;
        pix_i       : in std_logic_vector(23 downto 0);
        pix_o       : out std_logic_vector(23 downto 0);
        frame_x_pos : in std_logic_vector(11 downto 0);
        frame_y_pos : in std_logic_vector(11 downto 0);
        descriptor_pos_x : in std_logic_vector(10 downto 0);
        descriptor_pos_y : in std_logic_vector(10 downto 0);
        descriptor_fifo_empty : in std_logic;
        descriptor_fifo_full : in std_logic;
        clr_sel     : in std_logic_vector(1 downto 0);
        feature_paint  : out std_logic;
        pop_descriptor : out std_logic;
        reset_n     : out std_logic
    );
end frame_supervisor;

architecture rtl of frame_supervisor is
    signal started : std_logic := '0';
    signal pix_rgb  : std_logic_vector(23 downto 0);
    signal s_frame_x_pos : unsigned(11 downto 0);
    signal s_frame_y_pos : unsigned(11 downto 0);
    signal s_descriptor_pos_x : unsigned(11 downto 0);
    signal s_descriptor_pos_y : unsigned(11 downto 0);
    signal is_feature : std_logic := '0';
    signal x_match : std_logic := '0';
    signal y_match : std_logic := '0';
    signal x_right_match : std_logic := '0';
    signal x_left_match : std_logic := '0';
    signal y_up_match : std_logic := '0';
    signal y_down_match : std_logic := '0';
    signal is_feature_up : std_logic := '0';
    signal is_feature_down : std_logic := '0';
    signal is_feature_left : std_logic := '0';
    signal is_feature_right : std_logic := '0';
    signal to_paint : std_logic := '0';
    signal feat_pix : std_logic_vector(23 downto 0) := x"0000FF";
begin

    reset_process: process(clk)
    begin
        if rising_edge(clk) then
            if (rst and v_sync) = '1' then
                started <= '1';
                reset_n <= '0';
            else
                reset_n <= '1';
            end if;
        end if;
    end process reset_process;

    s_frame_x_pos <= unsigned(frame_x_pos);
    s_frame_y_pos <= unsigned(frame_y_pos);
    s_descriptor_pos_x <= unsigned(std_logic_vector("0"&descriptor_pos_x));
    s_descriptor_pos_y <= unsigned(std_logic_vector("0"&descriptor_pos_y));
    
    x_match <= '1' when (s_frame_x_pos+1 = s_descriptor_pos_x) else '0';
    x_right_match <= '1' when (s_frame_x_pos+2 = s_descriptor_pos_x) else '0';
    x_left_match <= '1' when (s_frame_x_pos = s_descriptor_pos_x) else '0';
    y_match <= '1' when (s_frame_y_pos = s_descriptor_pos_y) else '0';
    y_up_match <= '1' when (s_frame_y_pos-1 = s_descriptor_pos_y) else '0';
    y_down_match <= '1' when (s_frame_y_pos+1 = s_descriptor_pos_y) else '0';

    is_feature <= x_match and y_match;
    is_feature_up <= x_match and y_up_match;
    is_feature_down <= x_match and y_down_match;
    is_feature_left <= x_left_match and y_match;
    is_feature_right <= x_right_match and y_match;

    to_paint <= valid_pix and (is_feature or is_feature_left or is_feature_right);-- or is_feature_up or is_feature_down);

    process(clr_sel)
    begin
        case clr_sel is
            when "00" =>
                feat_pix <= x"0000FF";
            when "01" =>
                feat_pix <= x"00FF00";
            when "10" =>
                feat_pix <= x"FF0000";
            when "11" =>
                feat_pix <= x"FFFFFF";
            when others =>
                feat_pix <= x"000000";
        end case;
    end process;

    paint_process: process(clk)
    begin
        if rising_edge(clk) then
            if to_paint = '1' then
                pix_o <= feat_pix;
            else
                pix_o <= pix_i;
            end if;
            if (descriptor_fifo_full = '1' or is_feature_left = '1' or (unsigned(descriptor_pos_x) = to_unsigned(0,descriptor_pos_x'length) or unsigned(descriptor_pos_y) = to_unsigned(0,descriptor_pos_y'length))) and (descriptor_fifo_empty = '0') then
                pop_descriptor <= '1';
            else
                pop_descriptor <= '0';
            end if;

            feature_paint <= is_feature;
        end if;
    end process paint_process;

end rtl;
