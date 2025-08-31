----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 06/17/2024 01:15:57 PM
-- Module Name: orb_hdmi - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity orb_hdmi is
    Generic (
        ELEMENT_SIZE                    : integer := 8;
        ACONF_LINE_SIZE                 : integer := 60;
        ACONF_NUM_LINES                 : integer := 60;
        ACONF_NUM_SCALES                : integer := 1;
        ACONF_FEATURE_FIFO_SIZE         : integer := 128;
        ACONF_FEATURE_FIFO_ADDR_SIZE    : integer := 7;
        ACONF_DESCRIPTOR_FIFO_SIZE      : integer := 128;
        ACONF_DESCRIPTOR_FIFO_ADDR_SIZE : integer := 7;
        -- FAST parameters              
        DETECTOR_NUM_LINES              : integer := 7;
        DETECTOR_NUM_LINES_MIDDLE       : integer := 3;
        DETECTOR_LINE_SIZE              : integer := 7;
        DETECTOR_LINE_SIZE_MIDDLE       : integer := 3;
        BRESENHAM_CIRCLE_SIZE           : integer := 16;
        DIFF_THRESHOLD                  : signed := "000001111";
        DIFF_THRESHOLD_N                : signed := "111110001";
        NMS_NUM_LINES                   : integer := 3;
        NMS_NUM_LINES_MIDDLE            : integer := 1;
        NMS_LINE_SIZE                   : integer := 3;
        NMS_LINE_SIZE_MIDDLE            : integer := 1;
        FEATURE_FIFO_SIZE               : integer := 128;
        -- BRIEF parameters             
        GAUSSIAN_NUM_LINES              : integer := 7;
        GAUSSIAN_NUM_LINES_MIDDLE       : integer := 3;
        GAUSSIAN_LINE_SIZE              : integer := 7;
        GAUSSIAN_LINE_SIZE_MIDDLE       : integer := 3;
        ORIENTATION_NUM_LINES           : integer := 37;
        ORIENTATION_NUM_LINES_MIDDLE    : integer := 18;
        ORIENTATION_LINE_SIZE           : integer := 37;
        ORIENTATION_LINE_SIZE_MIDDLE    : integer := 18
    );
    Port ( 
        pix_clk:               in std_logic;
        hsync:                 in std_logic;
        vsync:                 in std_logic;
        pix:                   in std_logic_vector(23 downto 0);
        min_col:               in std_logic_vector(11 downto 0);
        max_col:               in std_logic_vector(11 downto 0);
        min_row:               in std_logic_vector(11 downto 0);
        max_row:               in std_logic_vector(11 downto 0);
        descriptor_pos_x:      in std_logic_vector(10 downto 0);
        descriptor_pos_y:      in std_logic_vector(10 downto 0);
        descriptor_fifo_empty: in std_logic;
        descriptor_fifo_full:  in std_logic;
        clr_sel:               in std_logic_vector(1 downto 0);
        rst:                   in std_logic;

        descriptor_ready:      out std_logic;
        descriptor:            out std_logic_vector(255 downto 0);
        pos_descriptor_y:      out std_logic_vector (10 downto 0);
        pos_descriptor_x:      out std_logic_vector (10 downto 0);
        --pop_pos_descriptor_y:  out std_logic_vector (10 downto 0);
        --pop_pos_descriptor_x:  out std_logic_vector (10 downto 0);
        pix_o:                 out std_logic_vector(23 downto 0);
        feature_paint:         out std_logic;
        pop_descriptor:        out std_logic;
        pix_out_crs:           out std_logic_vector(23 downto 0);
        pix_out_sqr:           out std_logic_vector(23 downto 0)
    );
end orb_hdmi;

architecture rtl of orb_hdmi is
    signal fpt_pix_out : std_logic_vector(23 downto 0);
    signal fpt_valid_pix : std_logic;
    signal fpt_frame_x_pos : std_logic_vector(11 downto 0);
    signal fpt_frame_y_pos : std_logic_vector(11 downto 0);
    signal fpt_h_position_o: std_logic_vector(11 downto 0);
    
    signal fs_reset_n : std_logic;
    
    signal rgb2bw_bw : std_logic_vector(7 downto 0);
    signal rgb2bw_valid_bw : std_logic;

    signal orb_pop_pos_descriptor_y : std_logic_vector(10 downto 0);
    signal orb_pop_pos_descriptor_x : std_logic_vector(10 downto 0);

    signal zero_s : std_logic := '0';
begin

    ORB: entity work.orb
        generic map(
            ELEMENT_SIZE                    => ELEMENT_SIZE,
            ACONF_LINE_SIZE                 => ACONF_LINE_SIZE,
            ACONF_NUM_LINES                 => ACONF_NUM_LINES,
            ACONF_NUM_SCALES                => ACONF_NUM_SCALES,
            ACONF_FEATURE_FIFO_SIZE         => ACONF_FEATURE_FIFO_SIZE,
            ACONF_FEATURE_FIFO_ADDR_SIZE    => ACONF_FEATURE_FIFO_ADDR_SIZE,
            ACONF_DESCRIPTOR_FIFO_SIZE      => ACONF_DESCRIPTOR_FIFO_SIZE,
            ACONF_DESCRIPTOR_FIFO_ADDR_SIZE => ACONF_DESCRIPTOR_FIFO_ADDR_SIZE,
            -- FAST parameters                    
            DETECTOR_NUM_LINES              => DETECTOR_NUM_LINES,              
            DETECTOR_NUM_LINES_MIDDLE       => DETECTOR_NUM_LINES_MIDDLE,       
            DETECTOR_LINE_SIZE              => DETECTOR_LINE_SIZE,              
            DETECTOR_LINE_SIZE_MIDDLE       => DETECTOR_LINE_SIZE_MIDDLE,       
            BRESENHAM_CIRCLE_SIZE           => BRESENHAM_CIRCLE_SIZE,           
            DIFF_THRESHOLD                  => DIFF_THRESHOLD,                  
            DIFF_THRESHOLD_N                => DIFF_THRESHOLD_N,                
            NMS_NUM_LINES                   => NMS_NUM_LINES,                   
            NMS_NUM_LINES_MIDDLE            => NMS_NUM_LINES_MIDDLE,            
            NMS_LINE_SIZE                   => NMS_LINE_SIZE,                   
            NMS_LINE_SIZE_MIDDLE            => NMS_LINE_SIZE_MIDDLE,            
            FEATURE_FIFO_SIZE               => FEATURE_FIFO_SIZE,               
            -- BRIEF parameters                         
            GAUSSIAN_NUM_LINES              => GAUSSIAN_NUM_LINES,              
            GAUSSIAN_NUM_LINES_MIDDLE       => GAUSSIAN_NUM_LINES_MIDDLE,       
            GAUSSIAN_LINE_SIZE              => GAUSSIAN_LINE_SIZE,              
            GAUSSIAN_LINE_SIZE_MIDDLE       => GAUSSIAN_LINE_SIZE_MIDDLE,       
            ORIENTATION_NUM_LINES           => ORIENTATION_NUM_LINES,           
            ORIENTATION_NUM_LINES_MIDDLE    => ORIENTATION_NUM_LINES_MIDDLE,    
            ORIENTATION_LINE_SIZE           => ORIENTATION_LINE_SIZE,           
            ORIENTATION_LINE_SIZE_MIDDLE    => ORIENTATION_LINE_SIZE_MIDDLE    
        )
        port map (
            clk => pix_clk,
            reset_n => fs_reset_n,
            pix_in => rgb2bw_bw,
            push => rgb2bw_valid_bw,
            pop_descriptor => zero_s,
            descriptor_ready => descriptor_ready,
            descriptor => descriptor,
            pos_descriptor_y => pos_descriptor_y,    
            pos_descriptor_x => pos_descriptor_x,   
            pop_pos_descriptor_y => orb_pop_pos_descriptor_y,
            pop_pos_descriptor_x => orb_pop_pos_descriptor_x
        );

    FRM_SUPRVIS: entity work.frame_supervisor
        port map (
            clk => pix_clk,
            rst => rst,
            v_sync => vsync,
            valid_pix => fpt_valid_pix,
            pix_i => pix,
            frame_x_pos => fpt_frame_x_pos,
            frame_y_pos => fpt_frame_y_pos,
            descriptor_pos_x => descriptor_pos_x,
            descriptor_pos_y => descriptor_pos_y,
            descriptor_fifo_empty => descriptor_fifo_empty,
            descriptor_fifo_full => descriptor_fifo_full,
            clr_sel => clr_sel,
            pix_o => pix_o,
            feature_paint => feature_paint,
            pop_descriptor => pop_descriptor,
            reset_n => fs_reset_n
        );

    RGB2BW: entity work.rgb2bw
        port map (
            clk => pix_clk,
            rgb => fpt_pix_out,
            valid_pix => fpt_valid_pix,
            bw => rgb2bw_bw,
            valid_bw => rgb2bw_valid_bw
        );

    FRM_POS_TRCK: entity work.frame_pos_tracking
        generic map (
            H_RES => ACONF_LINE_SIZE,
            V_RES => ACONF_NUM_LINES
        )
        port map (
            hsync => hsync,
            vsync => vsync,
            pix_clk => pix_clk,
            rst => rst,
            pix => pix,
            min_col => min_col,
            max_col => max_col,
            min_row => min_row,
            max_row => max_row,
            pix_out => fpt_pix_out,
            pix_out_crs => pix_out_crs,
            pix_out_sqr => pix_out_sqr,
            h_position_o => fpt_h_position_o,
            valid_pix => fpt_valid_pix,
            frame_x_pos => fpt_frame_x_pos,
            frame_y_pos => fpt_frame_y_pos
        );

end rtl;
