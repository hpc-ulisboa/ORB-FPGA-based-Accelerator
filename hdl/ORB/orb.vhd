----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 05/08/2024 10:04:23 AM
-- Module Name: orb - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity orb is
    generic (
        ELEMENT_SIZE    : integer := 8;
        ACONF_LINE_SIZE       : integer := 60;
        ACONF_NUM_LINES       : integer := 60;
        ACONF_NUM_SCALES      : integer := 2;
        ACONF_FEATURE_FIFO_SIZE: integer := 128;
        ACONF_FEATURE_FIFO_ADDR_SIZE: integer := 7;
        ACONF_DESCRIPTOR_FIFO_SIZE: integer := 128;
        ACONF_DESCRIPTOR_FIFO_ADDR_SIZE: integer := 7;
        ACONF_THETA_SIZE: natural := 3
    );
    Port ( 
        clk : in STD_LOGIC;
        reset_n : in STD_LOGIC;
        pix_in : in STD_LOGIC_VECTOR(ELEMENT_SIZE-1 downto 0);
        push : in STD_LOGIC;
        corner_thr : in std_logic_vector(8 downto 0);
        corner_thr_n : in std_logic_vector(8 downto 0);
        feature_ready : out std_logic;
        feature_descriptor : out std_logic_vector(255 downto 0);
        feature_pos_y : out std_logic_vector (10 downto 0);
        feature_pos_x : out std_logic_vector (10 downto 0);
        feature_score : out std_logic_vector (11 downto 0);
        feature_angle : out std_logic_vector (ACONF_THETA_SIZE-1+2 downto 0);
        feature_scale : out std_logic_vector (0 downto 0)
    );
end orb;

architecture rtl of orb is
    type is_feature_array is array (0 to ACONF_NUM_SCALES-1) of std_logic;
    type pos_feature_y_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(10 downto 0);
    type pos_feature_x_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(10 downto 0);
    type feature_score_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(11 downto 0);
    type descriptor_ready_array is array (0 to ACONF_NUM_SCALES-1) of std_logic;
    type feature_descriptor_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(255 downto 0);
    type pos_descriptor_x_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(10 downto 0);
    type pos_descriptor_y_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(10 downto 0);
    type descriptor_score_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(11 downto 0);
    type descriptor_angle_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(ACONF_THETA_SIZE-1+2  downto 0);
    type pix_in_array is array (0 to ACONF_NUM_SCALES-1) of std_logic_vector(ELEMENT_SIZE-1 downto 0);
    type push_array is array (0 to ACONF_NUM_SCALES-1) of std_logic;

    -- FAST parameters
    constant DETECTOR_NUM_LINES: integer := 7;
    constant DETECTOR_NUM_LINES_MIDDLE: integer := 3;
    constant DETECTOR_LINE_SIZE: integer := 7;
    constant DETECTOR_LINE_SIZE_MIDDLE: integer := 3;
    constant BRESENHAM_CIRCLE_SIZE : integer := 16;
    constant DIFF_THRESHOLD  : signed := "000001111";
    constant DIFF_THRESHOLD_N  : signed := "111110001";
    constant NMS_NUM_LINES: integer := 3;
    constant NMS_NUM_LINES_MIDDLE: integer := 1;
    constant NMS_LINE_SIZE: integer := 3;
    constant NMS_LINE_SIZE_MIDDLE: integer := 1;
    constant FEATURE_FIFO_SIZE: integer := 128;
    -- BRIEF parameters
    constant GAUSSIAN_NUM_LINES: integer := 7;
    constant GAUSSIAN_NUM_LINES_MIDDLE: integer := 3;
    constant GAUSSIAN_LINE_SIZE: integer := 7;
    constant GAUSSIAN_LINE_SIZE_MIDDLE: integer := 3;
    constant ORIENTATION_NUM_LINES: integer := 37;
    constant ORIENTATION_NUM_LINES_MIDDLE: integer := 18;
    constant ORIENTATION_LINE_SIZE: integer := 37;
    constant ORIENTATION_LINE_SIZE_MIDDLE: integer := 18;

    signal s_pix_in : pix_in_array := (others => (others => '0'));
    signal s_push : push_array := (others => '0');
    signal is_feature : is_feature_array;
    signal pos_feature_y : pos_feature_y_array;
    signal pos_feature_x : pos_feature_x_array;
    signal s_feature_score : feature_score_array; 
    signal s_descriptor_ready : descriptor_ready_array := (others => '0');
    signal s_descriptor : feature_descriptor_array := (others => (others => '0'));
    signal s_pos_descriptor_x : pos_descriptor_x_array := (others => (others => '0'));
    signal s_pos_descriptor_y : pos_descriptor_y_array := (others => (others => '0'));
    signal s_descriptor_score : descriptor_score_array := (others => (others => '0'));
    signal s_descriptor_angle : descriptor_angle_array := (others => (others => '0'));
    
    signal descriptors_ready : std_logic_vector(2 downto 0) := (others => '0');
    signal descriptor_delayed : std_logic := '0';
    signal descriptor_ready_delay : std_logic := '0';
    signal descriptor_delay : std_logic_vector(255 downto 0) := (others => '0');
    signal pos_descriptor_x_delay : std_logic_vector(10 downto 0) := (others => '0');
    signal pos_descriptor_y_delay : std_logic_vector(10 downto 0) := (others => '0');
    signal descriptor_score_delay : std_logic_vector(11 downto 0) := (others => '0');
    signal descriptor_angle_delay : std_logic_vector(ACONF_THETA_SIZE-1+2  downto 0) := (others => '0');
begin
    
    s_pix_in(0) <= pix_in;
    s_push(0)   <= push;
    
    gen_fast: for scale in 0 to ACONF_NUM_SCALES-1 generate
        scalar_generate : if not(scale=0) generate
            SCALAR: entity work.scalar
                generic map(
                    ELEMENT_SIZE => ELEMENT_SIZE,
                    LINE_SIZE    => ACONF_LINE_SIZE/(2**(scale-1)),
                    NUM_LINES    => ACONF_NUM_LINES/(2**(scale-1))
                )
                port map(
                    clk     => clk,
                    push_v  => s_pix_in(scale-1),
                    active  => s_push(scale-1),
                    reset_n => reset_n,
                    valid_pix_out => s_push(scale),
                    pix_out       => s_pix_in(scale)
                );
        end generate;
        
        FAST: entity work.fast_detector
            generic map (
                ELEMENT_SIZE => ELEMENT_SIZE,
                LINE_SIZE    => ACONF_LINE_SIZE/(2**scale),
                NUM_LINES    => ACONF_NUM_LINES/(2**scale),
                DETECTOR_NUM_LINES => DETECTOR_NUM_LINES,
                DETECTOR_NUM_LINES_MIDDLE => DETECTOR_NUM_LINES_MIDDLE,
                DETECTOR_LINE_SIZE => DETECTOR_LINE_SIZE,
                DETECTOR_LINE_SIZE_MIDDLE => DETECTOR_LINE_SIZE_MIDDLE,
                BRESENHAM_CIRCLE_SIZE => BRESENHAM_CIRCLE_SIZE,
                DIFF_THRESHOLD => DIFF_THRESHOLD,
                DIFF_THRESHOLD_N => DIFF_THRESHOLD_N,
                NMS_NUM_LINES => NMS_NUM_LINES,
                NMS_NUM_LINES_MIDDLE => NMS_NUM_LINES_MIDDLE,
                NMS_LINE_SIZE => NMS_LINE_SIZE,
                NMS_LINE_SIZE_MIDDLE => NMS_LINE_SIZE_MIDDLE
            )
            port map (
                clk => clk,
                reset_n => reset_n,
                push_v => s_pix_in(scale),
                active => s_push(scale),
                corner_thr   =>corner_thr,
                corner_thr_n =>corner_thr_n,
                is_feature => is_feature(scale),
                pos_feature_y => pos_feature_y(scale),
                pos_feature_x => pos_feature_x(scale),
                feature_score => s_feature_score(scale)
            );

        BRIEF: entity work.brief_construct
            generic map (
                ELEMENT_SIZE => ELEMENT_SIZE,
                LINE_SIZE => ACONF_LINE_SIZE/(2**scale),
                NUM_LINES => ACONF_NUM_LINES/(2**scale),
                FEATURE_FIFO_SIZE => ACONF_FEATURE_FIFO_SIZE,
                FEATURE_FIFO_ADDR_SIZE => ACONF_FEATURE_FIFO_ADDR_SIZE,
                GAUSSIAN_NUM_LINES => GAUSSIAN_NUM_LINES,
                GAUSSIAN_NUM_LINES_MIDDLE => GAUSSIAN_NUM_LINES_MIDDLE,
                GAUSSIAN_LINE_SIZE => GAUSSIAN_LINE_SIZE,
                GAUSSIAN_LINE_SIZE_MIDDLE => GAUSSIAN_LINE_SIZE_MIDDLE,
                ORIENTATION_NUM_LINES => ORIENTATION_NUM_LINES,
                ORIENTATION_NUM_LINES_MIDDLE => ORIENTATION_NUM_LINES_MIDDLE,
                ORIENTATION_LINE_SIZE => ORIENTATION_LINE_SIZE,
                ORIENTATION_LINE_SIZE_MIDDLE => ORIENTATION_LINE_SIZE_MIDDLE,
                THETA_SIZE => ACONF_THETA_SIZE
            )
            port map (
                clk => clk,
                reset_n => reset_n,
                push_v => s_pix_in(scale),
                active => s_push(scale),
                new_feature => is_feature(scale),
                pos_feature_y => pos_feature_y(scale),
                pos_feature_x => pos_feature_x(scale),
                feature_score => s_feature_score(scale),
                descriptor_ready => s_descriptor_ready(scale),
                descriptor => s_descriptor(scale),
                pos_descriptor_y => s_pos_descriptor_y(scale),
                pos_descriptor_x => s_pos_descriptor_x(scale),
                descriptor_score => s_descriptor_score(scale),
                descriptor_angle => s_descriptor_angle(scale)
            );

    end generate;

    -- TODO: The following lines will have to be changed should more scales be needed
    
    descriptors_ready <= descriptor_delayed&s_descriptor_ready(1)&s_descriptor_ready(0);

    descriptor_output: process(clk)
    begin
        if rising_edge(clk) then
            case descriptors_ready is
                when "100" =>
                    feature_ready <= descriptor_ready_delay;
                    feature_descriptor <= descriptor_delay;
                    feature_pos_y <= pos_descriptor_x_delay;
                    feature_pos_x <= pos_descriptor_y_delay;
                    feature_score <= descriptor_score_delay;
                    feature_angle <= descriptor_angle_delay;
                    feature_scale <= "1";
                    descriptor_delayed <= '0';
                when "001" =>
                    feature_ready <= s_descriptor_ready(0);
                    feature_descriptor <= s_descriptor(0);
                    feature_pos_y <= s_pos_descriptor_y(0);
                    feature_pos_x <= s_pos_descriptor_x(0);
                    feature_score <= s_descriptor_score(0);
                    feature_angle <= s_descriptor_angle(0);
                    feature_scale <= "0";
                    descriptor_delayed <= '0';
                when "010" =>
                    feature_ready <= s_descriptor_ready(1);
                    feature_descriptor <= s_descriptor(1);
                    feature_pos_y <= s_pos_descriptor_y(1)(s_pos_descriptor_y(1)'high-1 downto 0)&'0';
                    feature_pos_x <= s_pos_descriptor_x(1)(s_pos_descriptor_x(1)'high-1 downto 0)&'0';
                    feature_score <= s_descriptor_score(1);
                    feature_angle <= s_descriptor_angle(1);
                    feature_scale <= "1";
                    descriptor_delayed <= '0';
                when "011" =>
                    feature_ready <= s_descriptor_ready(0);
                    feature_descriptor <= s_descriptor(0);
                    feature_pos_y <= s_pos_descriptor_y(0);
                    feature_pos_x <= s_pos_descriptor_x(0);
                    feature_score <= s_descriptor_score(0);
                    feature_angle <= s_descriptor_angle(0);
                    feature_scale <= "0";
                    descriptor_delayed <= '1';
                when others =>
                    feature_ready <= '0';
                    feature_descriptor <= (others => '0');
                    feature_pos_y <= (others => '0');
                    feature_pos_x <= (others => '0');
                    feature_score <= (others => '0');
                    feature_angle <= (others => '0');
                    feature_scale <= (others => '0');
                    descriptor_delayed <= '0';
            end case;

            descriptor_ready_delay <= s_descriptor_ready(1); 
            descriptor_delay       <= s_descriptor(1); 
            pos_descriptor_x_delay <= s_pos_descriptor_y(1)(s_pos_descriptor_y(1)'high-1 downto 0)&'0'; 
            pos_descriptor_y_delay <= s_pos_descriptor_x(1)(s_pos_descriptor_x(1)'high-1 downto 0)&'0'; 
            descriptor_score_delay <= s_descriptor_score(1); 
            descriptor_angle_delay <= s_descriptor_angle(1); 
        end if;
    end process descriptor_output;

end rtl;
