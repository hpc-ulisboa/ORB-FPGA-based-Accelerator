----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 04/12/2024 03:21:11 PM
-- Module Name: brief_construct - structure
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
-- set_property FILE_TYPE {VHDL 2008} [get_files *.vhd]
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library intermodules_lib;
use intermodules_lib.intermodules_types.all;


entity brief_construct is
    generic (
        ELEMENT_SIZE    : integer := 8;
        LINE_SIZE       : integer := 60;
        NUM_LINES       : integer := 60;
        GAUSSIAN_NUM_LINES: integer := 7;
        GAUSSIAN_NUM_LINES_MIDDLE: integer := 3;
        GAUSSIAN_LINE_SIZE: integer := 7;
        GAUSSIAN_LINE_SIZE_MIDDLE: integer := 3;
        ORIENTATION_NUM_LINES: integer := 37;
        ORIENTATION_NUM_LINES_MIDDLE: integer := 18;
        ORIENTATION_LINE_SIZE: integer := 37;
        ORIENTATION_LINE_SIZE_MIDDLE: integer := 18;
        FEATURE_FIFO_SIZE: integer := 128;
        FEATURE_FIFO_ADDR_SIZE: integer := 7;
        THETA_SIZE: natural := 3
    );
    port (
        clk     : in std_logic;
        push_v  : in std_logic_vector((ELEMENT_SIZE-1) downto 0);
        active  : in std_logic;
        reset_n   : in std_logic;
        new_feature : in std_logic;
        pos_feature_y : in std_logic_vector (10 downto 0);
        pos_feature_x : in std_logic_vector (10 downto 0);
        feature_score : in std_logic_vector (11 downto 0);
        valid_orientation : out std_logic;
        pos_orientation_y : out std_logic_vector (10 downto 0);
        pos_orientation_x : out std_logic_vector (10 downto 0);
        quadrant : out std_logic_vector(1 downto 0);
        theta : out std_logic_vector(THETA_SIZE-1 downto 0);
        descriptor_ready : out std_logic;
        descriptor : out std_logic_vector(255 downto 0);
        pos_descriptor_y : out std_logic_vector (10 downto 0);
        pos_descriptor_x : out std_logic_vector (10 downto 0);
        descriptor_score : out std_logic_vector (11 downto 0);
        descriptor_angle : out std_logic_vector (THETA_SIZE-1+2 downto 0)
    );
end brief_construct;

architecture STRUCTURE of brief_construct is
  signal s_blurred_pixels : pix_array_t;
  signal s_valid_blurred_pixels : std_logic;
  signal s_pos_orientation_y, s_pos_orientation_x : std_logic_vector(10 downto 0);
  signal s_quadrant : std_logic_vector(1 downto 0);
  signal s_theta : std_logic_vector(THETA_SIZE-1 downto 0);
  signal descript_quadrant : std_logic_vector(1 downto 0);
  signal descript_theta : std_logic_vector(THETA_SIZE-1 downto 0);
  signal s_valid_orientation : std_logic;
  signal s_descriptor : std_logic_vector(255 downto 0);
  signal s_pop_feature : std_logic;
  signal s_pop_pos_feature_y, s_pop_pos_feature_x : std_logic_vector(pos_feature_x'high downto 0);
  signal s_pop_feature_score : std_logic_vector(feature_score'high downto 0);
  signal s_constructor_ready : std_logic;
  signal s_start_constructor : std_logic;
  constant brief_delay : integer := 47;
  type feature_angle_delay_buf_type is array (0 to (brief_delay+2-1)) of std_logic_vector (descriptor_angle'high downto 0);
  type feature_score_delay_buf_type is array (0 to (brief_delay-1)) of std_logic_vector (feature_score'high downto 0);
  signal feature_score_delay_buf : feature_score_delay_buf_type := (others => (others=> '0'));
  signal feature_angle_delay_buf : feature_angle_delay_buf_type := (others => (others=> '0'));

begin
    -- Holds the features detected by FAST in a FIFO waiting for the orientation to arrive to the same coordinate
    feature_fifo : entity work.feature_fifo
        generic map (
            FIFO_SIZE => FEATURE_FIFO_SIZE,
            ADDR_SIZE => FEATURE_FIFO_ADDR_SIZE,
            COORDINATE_SIZE => pos_feature_x'length,
            SCORE_SIZE => feature_score'length
        )
        port map (
            clk => clk,
            rst_n => reset_n,
            push_feature => new_feature,
            push_pos_feature_y => pos_feature_y,
            push_pos_feature_x => pos_feature_x,
            push_feature_score => feature_score,
            pop_feature => s_pop_feature,
            pop_pos_feature_y => s_pop_pos_feature_y,
            pop_pos_feature_x => s_pop_pos_feature_x,
            pop_feature_score => s_pop_feature_score
        );
    feature_score_delay: process(clk)
    begin
        if (rising_edge(clk)) then
            feature_score_delay_buf(0) <= s_pop_feature_score;
            for i in feature_score_delay_buf'high downto 1 loop
                feature_score_delay_buf(i) <= feature_score_delay_buf(i-1);
            end loop;
            descriptor_score <= feature_score_delay_buf(feature_score_delay_buf'high);
        end if;
    end process feature_score_delay;
    -- Compares feature FIFO head and Orienntation to command BRIEF constructionn
    fast_brief_coordinator : entity work.fast_brief_coordinator
        generic map (
            ELEMENT_SIZE => ELEMENT_SIZE,
            LINE_SIZE => LINE_SIZE,
            NUM_LINES => NUM_LINES,
            GAUSSIAN_NUM_LINES => GAUSSIAN_NUM_LINES,
            GAUSSIAN_NUM_LINES_MIDDLE => GAUSSIAN_NUM_LINES_MIDDLE,
            GAUSSIAN_LINE_SIZE => GAUSSIAN_LINE_SIZE,
            GAUSSIAN_LINE_SIZE_MIDDLE => GAUSSIAN_LINE_SIZE_MIDDLE,
            ORIENTATION_NUM_LINES => ORIENTATION_NUM_LINES,
            ORIENTATION_NUM_LINES_MIDDLE => ORIENTATION_NUM_LINES_MIDDLE,
            ORIENTATION_LINE_SIZE => ORIENTATION_LINE_SIZE,
            ORIENTATION_LINE_SIZE_MIDDLE => ORIENTATION_LINE_SIZE_MIDDLE
        )
        port map (
            clk => clk,
            rst_n => reset_n,
            pos_feature_y => s_pop_pos_feature_y,
            pos_feature_x => s_pop_pos_feature_x,
            pos_orientation_y => s_pos_orientation_y,
            pos_orientation_x => s_pos_orientation_x,
            constructor_available => s_constructor_ready,
            pop_feature => s_pop_feature,
            start_constructor => s_start_constructor
        );
    
    orientation_32_generate : if THETA_SIZE=5 generate
    orientation: entity work.orientation_module_32
        generic map (
            ELEMENT_SIZE => ELEMENT_SIZE,
            LINE_SIZE => LINE_SIZE,
            NUM_LINES => NUM_LINES,
            GAUSSIAN_NUM_LINES => GAUSSIAN_NUM_LINES,
            GAUSSIAN_NUM_LINES_MIDDLE => GAUSSIAN_NUM_LINES_MIDDLE,
            GAUSSIAN_LINE_SIZE => GAUSSIAN_LINE_SIZE,
            GAUSSIAN_LINE_SIZE_MIDDLE => GAUSSIAN_LINE_SIZE_MIDDLE,
            ORIENTATION_NUM_LINES => ORIENTATION_NUM_LINES,
            ORIENTATION_NUM_LINES_MIDDLE => ORIENTATION_NUM_LINES_MIDDLE,
            ORIENTATION_LINE_SIZE => ORIENTATION_LINE_SIZE,
            ORIENTATION_LINE_SIZE_MIDDLE => ORIENTATION_LINE_SIZE_MIDDLE
        )
        port map (
            clk => clk,
            push_v => push_v,
            active => active,
            reset_n => reset_n,
            valid_orientation => s_valid_orientation,
            pos_orientation_y => s_pos_orientation_y,
            pos_orientation_x => s_pos_orientation_x,
            quadrant => s_quadrant,
            theta => s_theta,
            valid_pix_out => s_valid_blurred_pixels,
            pix_out => s_blurred_pixels
        );
    end generate;
    orientation_16_generate : if THETA_SIZE=4 generate
        orientation: entity work.orientation_module_16
            generic map (
                ELEMENT_SIZE => ELEMENT_SIZE,
                LINE_SIZE => LINE_SIZE,
                NUM_LINES => NUM_LINES,
                GAUSSIAN_NUM_LINES => GAUSSIAN_NUM_LINES,
                GAUSSIAN_NUM_LINES_MIDDLE => GAUSSIAN_NUM_LINES_MIDDLE,
                GAUSSIAN_LINE_SIZE => GAUSSIAN_LINE_SIZE,
                GAUSSIAN_LINE_SIZE_MIDDLE => GAUSSIAN_LINE_SIZE_MIDDLE,
                ORIENTATION_NUM_LINES => ORIENTATION_NUM_LINES,
                ORIENTATION_NUM_LINES_MIDDLE => ORIENTATION_NUM_LINES_MIDDLE,
                ORIENTATION_LINE_SIZE => ORIENTATION_LINE_SIZE,
                ORIENTATION_LINE_SIZE_MIDDLE => ORIENTATION_LINE_SIZE_MIDDLE
            )
            port map (
                clk => clk,
                push_v => push_v,
                active => active,
                reset_n => reset_n,
                valid_orientation => s_valid_orientation,
                pos_orientation_y => s_pos_orientation_y,
                pos_orientation_x => s_pos_orientation_x,
                quadrant => s_quadrant,
                theta => s_theta,
                valid_pix_out => s_valid_blurred_pixels,
                pix_out => s_blurred_pixels
            );
    end generate;
    orientation_8_generate : if THETA_SIZE=3 generate
        orientation: entity work.orientation_module_8
            generic map (
                ELEMENT_SIZE => ELEMENT_SIZE,
                LINE_SIZE => LINE_SIZE,
                NUM_LINES => NUM_LINES,
                GAUSSIAN_NUM_LINES => GAUSSIAN_NUM_LINES,
                GAUSSIAN_NUM_LINES_MIDDLE => GAUSSIAN_NUM_LINES_MIDDLE,
                GAUSSIAN_LINE_SIZE => GAUSSIAN_LINE_SIZE,
                GAUSSIAN_LINE_SIZE_MIDDLE => GAUSSIAN_LINE_SIZE_MIDDLE,
                ORIENTATION_NUM_LINES => ORIENTATION_NUM_LINES,
                ORIENTATION_NUM_LINES_MIDDLE => ORIENTATION_NUM_LINES_MIDDLE,
                ORIENTATION_LINE_SIZE => ORIENTATION_LINE_SIZE,
                ORIENTATION_LINE_SIZE_MIDDLE => ORIENTATION_LINE_SIZE_MIDDLE
            )
            port map (
                clk => clk,
                push_v => push_v,
                active => active,
                reset_n => reset_n,
                valid_orientation => s_valid_orientation,
                pos_orientation_y => s_pos_orientation_y,
                pos_orientation_x => s_pos_orientation_x,
                quadrant => s_quadrant,
                theta => s_theta,
                valid_pix_out => s_valid_blurred_pixels,
                pix_out => s_blurred_pixels
            );
    end generate;

    orientation_generate : if THETA_SIZE=2 generate
        orientation : entity work.orientation_module
            generic map (
                ELEMENT_SIZE => ELEMENT_SIZE,
                LINE_SIZE => LINE_SIZE,
                NUM_LINES => NUM_LINES,
                GAUSSIAN_NUM_LINES => GAUSSIAN_NUM_LINES,
                GAUSSIAN_NUM_LINES_MIDDLE => GAUSSIAN_NUM_LINES_MIDDLE,
                GAUSSIAN_LINE_SIZE => GAUSSIAN_LINE_SIZE,
                GAUSSIAN_LINE_SIZE_MIDDLE => GAUSSIAN_LINE_SIZE_MIDDLE,
                ORIENTATION_NUM_LINES => ORIENTATION_NUM_LINES,
                ORIENTATION_NUM_LINES_MIDDLE => ORIENTATION_NUM_LINES_MIDDLE,
                ORIENTATION_LINE_SIZE => ORIENTATION_LINE_SIZE,
                ORIENTATION_LINE_SIZE_MIDDLE => ORIENTATION_LINE_SIZE_MIDDLE
            )
            port map (
                clk => clk,
                push_v => push_v,
                active => active,
                reset_n => reset_n,
                valid_orientation => s_valid_orientation,
                pos_orientation_y => s_pos_orientation_y,
                pos_orientation_x => s_pos_orientation_x,
                quadrant => s_quadrant,
                theta => s_theta,
                valid_pix_out => s_valid_blurred_pixels,
                pix_out => s_blurred_pixels
            );
    end generate;
    feature_angle_delay: process(clk)
    begin
        if (rising_edge(clk)) then
            --feature_angle_delay_buf(0) <= s_quadrant&s_theta;
            --for i in feature_angle_delay_buf'high downto 1 loop
            --    feature_angle_delay_buf(i) <= feature_angle_delay_buf(i-1);
            --end loop;
            descriptor_angle <= descript_quadrant&descript_theta;
        end if;
    end process feature_angle_delay;
    descriptor_construct : entity work.descriptor_construct
      generic map (
        ELEMENT_SIZE => ELEMENT_SIZE,
        LINE_SIZE => LINE_SIZE,
        NUM_LINES => NUM_LINES,
        GAUSSIAN_NUM_LINES => GAUSSIAN_NUM_LINES,
        GAUSSIAN_NUM_LINES_MIDDLE => GAUSSIAN_NUM_LINES_MIDDLE,
        GAUSSIAN_LINE_SIZE => GAUSSIAN_LINE_SIZE,
        GAUSSIAN_LINE_SIZE_MIDDLE => GAUSSIAN_LINE_SIZE_MIDDLE,
        ORIENTATION_NUM_LINES => ORIENTATION_NUM_LINES,
        ORIENTATION_NUM_LINES_MIDDLE => ORIENTATION_NUM_LINES_MIDDLE,
        ORIENTATION_LINE_SIZE => ORIENTATION_LINE_SIZE,
        ORIENTATION_LINE_SIZE_MIDDLE => ORIENTATION_LINE_SIZE_MIDDLE,
        THETA_SIZE => THETA_SIZE
      )
      port map (
        clk => clk,
        reset_n => reset_n,
        valid_orientation => s_valid_orientation,
        pos_orientation_y => s_pos_orientation_y,
        pos_orientation_x => s_pos_orientation_x,
        quadrant => s_quadrant,
        theta => s_theta,
        valid_pix_in => s_valid_blurred_pixels,
        pix_in => s_blurred_pixels,
        descriptor => descriptor,
        pos_descriptor_y => pos_descriptor_y,
        pos_descriptor_x => pos_descriptor_x,
        start_constr => s_start_constructor,
        constructor_ready => s_constructor_ready,
        descriptor_ready => descriptor_ready,
        quadrant_o => descript_quadrant,
        theta_o => descript_theta
      );

    valid_orientation <= s_valid_blurred_pixels;
    pos_orientation_y <= s_pos_orientation_y;
    pos_orientation_x <= s_pos_orientation_x;
    quadrant <= s_quadrant;
    theta <= s_theta;

end STRUCTURE;
