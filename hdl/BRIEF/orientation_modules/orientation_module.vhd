----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 02/09/2024 03:22:36 PM
-- Module Name: orientation_module - behavioral
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.NUMERIC_STD.to_unsigned;

library intermodules_lib;
use intermodules_lib.all;


entity orientation_module is
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
        ORIENTATION_LINE_SIZE_MIDDLE: integer := 18
    );
    port (
        clk     : in std_logic;
        push_v  : in std_logic_vector((ELEMENT_SIZE-1) downto 0);
        active  : in std_logic;
        reset_n   : in std_logic;
        valid_orientation : out std_logic;
        pos_orientation_y : out std_logic_vector (10 downto 0);
        pos_orientation_x : out std_logic_vector (10 downto 0);
        quadrant : out std_logic_vector(1 downto 0);
        theta : out std_logic_vector(1 downto 0);
        valid_pix_out : out std_logic;
        pix_out : out intermodules_types.pix_array_t
    );
end orientation_module;

architecture Behavioral of orientation_module is
    constant pix2orientation_delay : natural := 11;

    type gaussian_line_sr is array (0 to (LINE_SIZE-1)) of std_logic_vector((ELEMENT_SIZE-1) downto 0);
    type gaussian_mult_line_sr is array (0 to (GAUSSIAN_NUM_LINES-1)) of gaussian_line_sr;
    type orientation_line_sr is array (0 to ((LINE_SIZE-GAUSSIAN_LINE_SIZE+1)-1)) of unsigned((ELEMENT_SIZE-1) downto 0);
    type orientation_mult_line_sr is array (0 to (ORIENTATION_NUM_LINES-1)) of orientation_line_sr;
    type gaussian_window_line_sr is array (0 to (GAUSSIAN_LINE_SIZE-1)) of unsigned((ELEMENT_SIZE-1) downto 0);
    type gaussian_window_sr is array (0 to (GAUSSIAN_NUM_LINES-1)) of gaussian_window_line_sr;
    type orientation_window_line_sr is array (0 to (ORIENTATION_LINE_SIZE-1)) of unsigned((ELEMENT_SIZE-1) downto 0);
    type orientation_window_sr is array (0 to (ORIENTATION_NUM_LINES-1)) of orientation_window_line_sr;
    type position_type is record
        x : integer;
        y : integer;
    end record;
    type column_type is array (0 to (ORIENTATION_NUM_LINES-1)) of unsigned((ELEMENT_SIZE-1) downto 0);
    type gaussian_kernel_type is array (0 to GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE-1) of unsigned(8 downto 0);--unsigned(8 downto 0);
    type gaussian_sum_level_1_type is array (0 to GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE-1) of unsigned(ELEMENT_SIZE+9-1 downto 0); -- Max is x400
    type gaussian_sum_level_2_type is array (0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/2+1-1)) of unsigned(ELEMENT_SIZE+10-1 downto 0);
    type gaussian_sum_level_3_type is array (0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/4+1-1)) of unsigned(ELEMENT_SIZE+10-1 downto 0);
    type gaussian_sum_level_4_type is array (0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/8+1-1)) of unsigned(ELEMENT_SIZE+11-1 downto 0);
    type gaussian_sum_level_5_type is array (0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/16+1-1)) of unsigned(ELEMENT_SIZE+12-1 downto 0);
    type gaussian_sum_level_6_type is array (0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/32+1-1)) of unsigned(ELEMENT_SIZE+12-1 downto 0);
    type column_sum_level_1_type is array (0 to  ORIENTATION_NUM_LINES/2)      of unsigned(ELEMENT_SIZE+1 -1  downto 0); -- Max is x400
    type column_sum_level_2_type is array (0 to (ORIENTATION_NUM_LINES/4+1-1)) of unsigned(ELEMENT_SIZE+2-1 downto 0);
    type column_sum_level_3_type is array (0 to (ORIENTATION_NUM_LINES/8+1-1)) of unsigned(ELEMENT_SIZE+3-1 downto 0);
    type column_sum_level_4_type is array (0 to (ORIENTATION_NUM_LINES/16+1-1))of unsigned(ELEMENT_SIZE+4-1 downto 0);
    type column_sum_level_5_type is array (0 to (ORIENTATION_NUM_LINES/32+1-1))of unsigned(ELEMENT_SIZE+5-1 downto 0);
    type column_sum_delay_type   is array (0 to  ORIENTATION_NUM_LINES-1)    of unsigned(ELEMENT_SIZE+7-1 downto 0);
    type y_moment_sum_level_1_type is array (0 to  ORIENTATION_NUM_LINES-1)      of signed(ELEMENT_SIZE+6+1-1 downto 0); -- Max is 255*18 (+1 signal bit)
    type y_moment_sum_level_2_type is array (0 to  ORIENTATION_NUM_LINES/2+1-1)  of signed(ELEMENT_SIZE+6+1-1 downto 0); -- Max is 255*(18+17) (+1 signal bit)
    type y_moment_sum_level_3_type is array (0 to (ORIENTATION_NUM_LINES/4+1-1)) of signed(ELEMENT_SIZE+7+1-1 downto 0); -- Max is 255*(18+17+16+15) (+1 signal bit)
    type y_moment_sum_level_4_type is array (0 to (ORIENTATION_NUM_LINES/8+1-1)) of signed(ELEMENT_SIZE+7+1-1 downto 0); -- Max is 255*(18+17+16+15+14+13+12+11) (+1 signal bit)
    type y_moment_sum_level_5_type is array (0 to (ORIENTATION_NUM_LINES/16+1-1))of signed(ELEMENT_SIZE+8+1-1 downto 0); -- Max is 255*(18+17+16+15+14+13+12+11+10+9+8+7+6+5+4+3) (+1 signal bit)
    type y_moment_sum_level_6_type is array (0 to (ORIENTATION_NUM_LINES/32+1-1))of signed(ELEMENT_SIZE+8+1-1 downto 0); -- Max is 255*(18+17+16+15+14+13+12+11+10+9+8+7+6+5+4+3+2+1) (+1 signal bit)
    type y_moment_weigths_type is array (0 to (ORIENTATION_NUM_LINES+1-1)) of signed(ELEMENT_SIZE+1-1 downto 0);
    type y_moment_delay_type is array (0 to  ORIENTATION_NUM_LINES-1) of signed(ELEMENT_SIZE+8+1-1 downto 0);
    type orientation_pos_delay_type is array (0 to pix2orientation_delay-1) of position_type;
    constant gaussian_kernel : gaussian_kernel_type := ("000000001","000000110","000001111","000010100","000001111","000000110","000000001", --(1, 6,  15, 20, 15, 6,  1,
                                                        "000000110","000100100","001011010","001111000","001011010","000100100","000000110", -- 6, 36, 90, 120,90, 36, 6,
                                                        "000001111","001011010","011100001","100101100","011100001","001011010","000001111", -- 15,90, 225,300,225,90, 15,
                                                        "000010100","001111000","100101100","110010000","100101100","001111000","000010100", -- 20,120,300,400,300,120,20,
                                                        "000001111","001011010","011100001","100101100","011100001","001011010","000001111", -- 15,90, 225,300,225,90, 15,
                                                        "000000110","000100100","001011010","001111000","001011010","000100100","000000110", -- 6, 36, 90, 120,90, 36, 6, 
                                                        "000000001","000000110","000001111","000010100","000001111","000000110","000000001");-- 1, 6,  15, 20, 15, 6,  1);
    signal sr_gaussian : gaussian_mult_line_sr := (others => (others => (others => '0')));
    signal wb_gaussian : gaussian_window_sr := (others => (others => (others => '0')));
    signal sr_orientation : orientation_mult_line_sr := (others => (others => (others => '0')));
    signal wb_orientation : orientation_window_sr := (others => (others => (others => '0')));
    signal column_in : column_type := (others => (others => '0'));
    signal gaussian_sum_level_1     : gaussian_sum_level_1_type := (others => (others => '0'));
    signal gaussian_sum_level_1_r   : gaussian_sum_level_1_type := (others => (others => '0'));
    signal gaussian_sum_level_2     : gaussian_sum_level_2_type := (others => (others => '0'));
    signal gaussian_sum_level_2_r   : gaussian_sum_level_2_type := (others => (others => '0'));
    signal gaussian_sum_level_3     : gaussian_sum_level_3_type := (others => (others => '0'));
    signal gaussian_sum_level_3_r   : gaussian_sum_level_3_type := (others => (others => '0'));
    signal gaussian_sum_level_4     : gaussian_sum_level_4_type := (others => (others => '0'));
    signal gaussian_sum_level_4_r   : gaussian_sum_level_4_type := (others => (others => '0'));
    signal gaussian_sum_level_5     : gaussian_sum_level_5_type := (others => (others => '0'));
    signal gaussian_sum_level_5_r   : gaussian_sum_level_5_type := (others => (others => '0'));
    signal gaussian_sum_level_6     : gaussian_sum_level_6_type := (others => (others => '0'));
    signal gaussian_sum_level_6_r   : gaussian_sum_level_6_type := (others => (others => '0'));
    signal gaussian_sum_level_7     : unsigned(ELEMENT_SIZE+12-1 downto 0) := (others => '0');
    signal gaussian_sum_level_7_r   : unsigned(ELEMENT_SIZE+12-1 downto 0) := (others => '0');
    signal pos_gaussian : position_type := (0, 0);
    signal pos_gaussian_1 : position_type := (0, 0);
    signal pos_gaussian_2 : position_type := (0, 0);
    signal pos_gaussian_3 : position_type := (0, 0);
    signal pos_gaussian_4 : position_type := (0, 0);
    signal pos_gaussian_5 : position_type := (0, 0);
    signal pos_gaussian_6 : position_type := (0, 0);
    signal pos_gaussian_7 : position_type := (0, 0);
    signal pos_orientation : position_type := (0, 0);
    signal pos_orientation_1 : position_type := (0, 0);
    signal pos_orientation_2 : position_type := (0, 0);
    signal pos_orientation_exit : position_type := (0, 0);
    signal pos_orientation_delay : orientation_pos_delay_type := (others => (0, 0));
    signal gaussian_counter : integer := 1;
    signal gaussian_started : std_logic := '0';
    signal orientation_counter : integer := 1;
    signal orientation_started : std_logic := '0';
    signal valid_gaussian_window : std_logic := '0';
    signal valid_product_vector : std_logic := '0';
    signal valid_sum_level_2 : std_logic := '0';
    signal valid_sum_level_3 : std_logic := '0';
    signal valid_sum_level_4 : std_logic := '0';
    signal valid_sum_level_5 : std_logic := '0';
    signal valid_sum_level_6 : std_logic := '0';
    signal valid_sum_level_7 : std_logic := '0';
    signal valid_gaussian: std_logic := '0';
    signal valid_orientation_column : std_logic := '0';
    signal column_sum_level_1 : column_sum_level_1_type := (others => (others => '0'));
    signal column_sum_level_2 : column_sum_level_2_type := (others => (others => '0'));
    signal column_sum_level_3 : column_sum_level_3_type := (others => (others => '0'));
    signal column_sum_level_4 : column_sum_level_4_type := (others => (others => '0'));
    signal column_sum_level_5 : column_sum_level_5_type := (others => (others => '0'));
    signal column_in_sum : unsigned(ELEMENT_SIZE+7-1 downto 0) := (others => '0');
    signal column_sum_delay_sr : column_sum_delay_type := (others => (others => '0'));
    signal valid_column_sum_level_1 : std_logic := '0';
    signal valid_column_sum_level_2 : std_logic := '0';
    signal valid_column_sum_level_3 : std_logic := '0';
    signal valid_column_sum_level_4 : std_logic := '0';
    signal valid_column_sum_level_5 : std_logic := '0';
    signal valid_column_in_sum : std_logic := '0';
    signal valid_column_in_sum_delay : std_logic_vector(0 to  ORIENTATION_NUM_LINES-1-1) := (others => '0');
    signal y_moment_sum_level_1 : y_moment_sum_level_1_type := (others => (others => '0'));
    signal y_moment_sum_level_2 : y_moment_sum_level_2_type := (others => (others => '0'));
    signal y_moment_sum_level_3 : y_moment_sum_level_3_type := (others => (others => '0'));
    signal y_moment_sum_level_4 : y_moment_sum_level_4_type := (others => (others => '0'));
    signal y_moment_sum_level_5 : y_moment_sum_level_5_type := (others => (others => '0'));
    signal y_moment_sum_level_6 : y_moment_sum_level_6_type := (others => (others => '0'));
    signal y_moment_sum : signed(ELEMENT_SIZE+8+1-1 downto 0) := (others => '0');
    signal y_moment_delay_sr : y_moment_delay_type := (others => (others => '0'));
    signal valid_y_moment_sum_level_1 : std_logic := '0';
    signal valid_y_moment_sum_level_2 : std_logic := '0';
    signal valid_y_moment_sum_level_3 : std_logic := '0';
    signal valid_y_moment_sum_level_4 : std_logic := '0';
    signal valid_y_moment_sum_level_5 : std_logic := '0';
    signal valid_y_moment_sum_level_6 : std_logic := '0';
    signal valid_y_moment_in_sum : std_logic := '0';
    signal y_moment_started : std_logic := '0';
    signal valid_y_moment_delay : std_logic_vector(0 to  9-1-1) := (others => '0');
    signal valid_orientation_delay : std_logic_vector(0 to  12) := (others => '0');
    signal valid_orientation_check_vector : std_logic := '0';
    signal valid_orientation_check : std_logic := '0';
    constant orientation_sr_line_size: integer := (LINE_SIZE-GAUSSIAN_LINE_SIZE+1);
    constant orientation_sr_num: integer := (NUM_LINES-GAUSSIAN_NUM_LINES+1);
    signal orientation_check_vector : std_logic_vector (7 downto 0) := (others => '0');
    signal orientation_check : std_logic := '0';
    signal gaussian_result : unsigned(ELEMENT_SIZE-1 downto 0);
    signal m00_1 : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m00   : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m00_delayed : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m00_delayed_0 : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m10_aux_1 : signed(ELEMENT_SIZE+13-1 downto 0) := (others => '0');
    signal m10_1 : signed(ELEMENT_SIZE+13-1 downto 0) := (others => '0');
    signal m10_2 : signed(ELEMENT_SIZE+14-1 downto 0) := (others => '0');
    signal m10_3 : signed(ELEMENT_SIZE+15-1 downto 0) := (others => '0');
    signal m10 : signed(ELEMENT_SIZE+15-1 downto 0) := (others => '0'); -- 255*(18+17+16+15+14+13+12+11+10+9+8+7+6+5+4+3+2+1)*(18+19+2+1)*2= 3.488.400
    signal m10_n : std_logic_vector(ELEMENT_SIZE+15-1 downto 0) := (others => '0'); -- 255*(18+17+16+15+14+13+12+11+10+9+8+7+6+5+4+3+2+1)*(18+19+2+1)*2= 3.488.400
    signal m10_abs : unsigned(ELEMENT_SIZE+15-1 downto 0) := (others => '0');
    signal m10_delayed : signed(ELEMENT_SIZE+15-1 downto 0) := (others => '0');
    signal m01_1 : signed(ELEMENT_SIZE+9+1-1 downto 0) := (others => '0');
    signal m01_2 : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m01_3 : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m01_delay_1 : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m01_delay_2 : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m01_delay_3 : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0');
    signal m01 : signed(ELEMENT_SIZE+13+1-1 downto 0) := (others => '0'); -- 255*(18+17+16+15+14+13+12+11+10+9+8+7+6+5+4+3+2+1)*(18+19+2+1)*2= 3.488.400
    signal m01_abs : unsigned(m01'high downto 0) := (others => '0');
    signal m01_abs_delayed : unsigned(m01_abs'high downto 0) := (others => '0');
    signal m01_n : std_logic_vector(m01'high downto 0) := (others => '0'); -- 255*(18+17+16+15+14+13+12+11+10+9+8+7+6+5+4+3+2+1)*(18+19+2+1)*2= 3.488.400
    signal m01_delayed : signed(m01'high downto 0) := (others => '0');
    signal valid_m10_1 : std_logic := '0';
    signal valid_m10_2 : std_logic := '0';
    signal valid_m10_3 : std_logic := '0';
    signal valid_m10   : std_logic := '0';
    signal valid_m10_delayed : std_logic := '0';
    signal valid_m00_1 : std_logic := '0';
    signal valid_m00   : std_logic := '0';
    signal valid_m00_delayed : std_logic := '0';
    signal quadrant_s : std_logic_vector(1 downto 0) := (others => '0');
    signal quadrant_delayed : std_logic_vector(1 downto 0) := (others => '0');
    signal quadrant_aux : std_logic_vector(1 downto 0) := (others => '0');
    signal tan_calc_1 : std_logic_vector(ELEMENT_SIZE+15+2+1-1 downto 0) := (others => '0');
    signal tan_calc_2 : std_logic_vector(ELEMENT_SIZE+15+2+1-1 downto 0) := (others => '0');
    signal tan_calc_3 : signed(ELEMENT_SIZE+15+2+1-1 downto 0) := (others => '0');
    signal tan_calc_4 : signed(ELEMENT_SIZE+15+2+1-1 downto 0) := (others => '0');
    signal tan_calc_5 : std_logic_vector(ELEMENT_SIZE+15+4+1-1 downto 0) := (others => '0');
    signal tan_calc_6 : signed(ELEMENT_SIZE+15+2+4+1-1 downto 0) := (others => '0');
    signal tan_result_3  : signed(ELEMENT_SIZE+15+2+4+1-1 downto 0) := (others => '0');
    signal tan_result_3_r_int: unsigned(ELEMENT_SIZE+15+2+4+1-5-1 downto 0) := (others => '0');
    signal tan_result_1 : signed(ELEMENT_SIZE+15+2+1+1-1 downto 0) := (others => '0');
    signal tan_result_1_r_int : unsigned(ELEMENT_SIZE+15+2+1+1-5-1 downto 0) := (others => '0');
    signal tan_result_4 : signed(ELEMENT_SIZE+15+2+5+1-1 downto 0) := (others => '0');
    signal tan_result_4_r_int : unsigned(ELEMENT_SIZE+15+2+5+1-5-1 downto 0) := (others => '0');
    signal tan_result_2 : signed(ELEMENT_SIZE+15+4+1-1 downto 0) := (others => '0');
    signal tan_result_2_r_int : unsigned(ELEMENT_SIZE+15+4+1-5-1 downto 0) := (others => '0');
    signal tan_compare : std_logic_vector(3 downto 0) := (others => '0');
    signal tan_compare_r : std_logic_vector(3 downto 0) := (others => '0');
    signal theta_internal : std_logic_vector(1 downto 0) := (others => '0');

    constant y_moment_last_i : natural := y_moment_sum'high;

begin

    line_buffers_gaussian: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                sr_gaussian(0)(0) <= push_v;
                for i in (LINE_SIZE-1) downto 1 loop
                    sr_gaussian(0)(i) <= sr_gaussian(0)(i-1);
                end loop;
                for line in 1 to GAUSSIAN_NUM_LINES-1 loop
                    sr_gaussian(line)(0) <= sr_gaussian(line-1)(LINE_SIZE-1);
                    for i in (LINE_SIZE-1) downto 1 loop
                        sr_gaussian(line)(i) <= sr_gaussian(line)(i-1);
                    end loop;
                end loop;
                --pop_v <= sr_gaussian(GAUSSIAN_NUM_LINES-1)(LINE_SIZE-1);
            end if;
        end if;
    end process line_buffers_gaussian;

    window_buf_gaussian: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                for line in 0 to GAUSSIAN_NUM_LINES-1 loop
                    wb_gaussian(line)(GAUSSIAN_LINE_SIZE -1) <= unsigned(sr_gaussian(GAUSSIAN_NUM_LINES-1-line)(LINE_SIZE-1));
                    for i in 0 to (GAUSSIAN_LINE_SIZE-2) loop
                        wb_gaussian(line)(i) <= wb_gaussian(line)(i+1);
                    end loop;
                end loop;
            end if;
        end if;

    end process window_buf_gaussian;

    gaussian_position: process(clk)
    begin
        if (rising_edge(clk)) then
            if reset_n = '1' then
                if (active = '1') then
                    if gaussian_counter >= (LINE_SIZE*NUM_LINES) then
                        gaussian_counter <= 1; --  Starting the gaussian at 1 makes it be advanced by 1 clk cycle
                    else
                        gaussian_counter <= gaussian_counter + 1;
                    end if;

                    if gaussian_started = '0' then -- Starts counter when window buffer is full
                        if gaussian_counter > GAUSSIAN_LINE_SIZE * (LINE_SIZE + 1) - 1 - GAUSSIAN_LINE_SIZE_MIDDLE then -- Last (+1) accounts for 1 clk cycle delay
                            gaussian_started <= '1';
                            pos_gaussian.y <= GAUSSIAN_LINE_SIZE_MIDDLE;
                            pos_gaussian.x <= 0;
                        end if;
                    else
                        if (gaussian_counter >= (LINE_SIZE*NUM_LINES)) then
                            gaussian_started <= '0';
                        else
                            gaussian_started <= gaussian_started;
                        end if;
                        if (pos_gaussian.x >= (LINE_SIZE - 1)) then
                            pos_gaussian.y <= pos_gaussian.y + 1;
                            pos_gaussian.x <= 0;
                        else
                            pos_gaussian.x <= pos_gaussian.x + 1;
                        end if;
                    end if;

                    if (pos_gaussian.y >= GAUSSIAN_NUM_LINES_MIDDLE and
 pos_gaussian.y < NUM_LINES - GAUSSIAN_NUM_LINES_MIDDLE and
 pos_gaussian.x + 1 < LINE_SIZE - GAUSSIAN_LINE_SIZE_MIDDLE and
 pos_gaussian.x + 1>= GAUSSIAN_LINE_SIZE_MIDDLE) then
                        valid_gaussian_window <= '1';
                    else
                        valid_gaussian_window <= '0';
                    end if;

                    valid_product_vector <= valid_gaussian_window;
                    valid_sum_level_2 <= valid_product_vector;
                    valid_sum_level_3 <= valid_sum_level_2;
                    valid_sum_level_4 <= valid_sum_level_3;
                    valid_sum_level_5 <= valid_sum_level_4;
                    valid_sum_level_6 <= valid_sum_level_5;
                    valid_sum_level_7 <= valid_sum_level_6;
                    valid_gaussian<= valid_sum_level_7;
                    valid_pix_out <= valid_sum_level_7;

                    pos_gaussian_1 <= pos_gaussian;
                    pos_gaussian_2 <= pos_gaussian_1;
                    pos_gaussian_3 <= pos_gaussian_2;
                    pos_gaussian_4 <= pos_gaussian_3;
                    pos_gaussian_5 <= pos_gaussian_4;
                    pos_gaussian_6 <= pos_gaussian_5;
                    pos_gaussian_7 <= pos_gaussian_6;
                end if;
            else
                gaussian_counter <= 1; --  Starting the gaussian at 1 makes it be advanced by 1 clk cycle
                gaussian_started <= '0';
                pos_gaussian<=(0, 0);

                valid_product_vector <= '0';
                valid_sum_level_2 <= '0';
                valid_sum_level_3 <= '0';
                valid_sum_level_4 <= '0';
                valid_sum_level_5 <= '0';
                valid_sum_level_6 <='0';
                valid_sum_level_7 <='0';
                valid_gaussian<='0';
                valid_gaussian_window <= '0';

                pos_gaussian_1 <= (0, 0);
                pos_gaussian_2 <= (0, 0);
                pos_gaussian_3 <= (0, 0);
                pos_gaussian_4 <= (0, 0);
                pos_gaussian_5 <= (0, 0);
                pos_gaussian_6 <= (0, 0);
                pos_gaussian_7 <= (0, 0);
            end if;
        end if;
    end process gaussian_position;

    -- Calculations for gaussian start here
    -- level 1
    gen_gaussian_l1_rows: for i in 0 to (GAUSSIAN_NUM_LINES-1) generate
        gen_gaussian_l1_cols: for j in 0 to (GAUSSIAN_LINE_SIZE-1) generate
            gaussian_sum_level_1(i*GAUSSIAN_LINE_SIZE+j) <= wb_gaussian(i)(j) * gaussian_kernel(i*GAUSSIAN_LINE_SIZE+j);
        end generate gen_gaussian_l1_cols;
    end generate gen_gaussian_l1_rows;

    reg_gaussian_sum_level_1: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_gaussian_window = '1' then
                    for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE-1) loop
                        gaussian_sum_level_1_r(i) <= gaussian_sum_level_1(i);
                    end loop;
                else
                    gaussian_sum_level_1_r <= (others => (others => '0'));
                end if;
            end if;
        end if;
    end process reg_gaussian_sum_level_1;

    -- level 2
    gaussian_sum_level_2(GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/2) <= '0'&gaussian_sum_level_1_r(GAUSSIAN_LINE_SIZE*GAUSSIAN_LINE_SIZE-1);
    gen_gaussian_l2: for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/2-1) generate
        gaussian_sum_level_2(i) <= ('0'&gaussian_sum_level_1_r(i*2))+('0'&gaussian_sum_level_1_r(i*2+1));
    end generate gen_gaussian_l2;

    reg_gaussian_sum_level_2: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_product_vector = '1' then
                    for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/2+1-1) loop
                        gaussian_sum_level_2_r(i) <= gaussian_sum_level_2(i);
                    end loop;
                else
                    gaussian_sum_level_2_r <= (others => (others => '0'));
                end if;
            end if;
        end if;
    end process reg_gaussian_sum_level_2;

    -- level 3
    gaussian_sum_level_3(GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/4) <= gaussian_sum_level_2_r(GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/2);
    gen_gaussian_l3: for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/4-1) generate
        gaussian_sum_level_3(i) <= gaussian_sum_level_2_r(i*2)+gaussian_sum_level_2_r(i*2+1);
    end generate gen_gaussian_l3;

    reg_gaussian_sum_level_3: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_sum_level_2 = '1' then
                    for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/4+1-1) loop
                        gaussian_sum_level_3_r(i) <= gaussian_sum_level_3(i);
                    end loop;
                else
                    gaussian_sum_level_3_r <= (others => (others => '0'));
                end if;
            end if;
        end if;
    end process reg_gaussian_sum_level_3;

    -- level 4
    gaussian_sum_level_4(GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/8) <= '0'&gaussian_sum_level_3_r(GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/4);
    gen_gaussian_l4: for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/8-1) generate
        gaussian_sum_level_4(i) <= ('0'&gaussian_sum_level_3_r(i*2))+('0'&gaussian_sum_level_3_r(i*2+1));
    end generate gen_gaussian_l4;

    reg_gaussian_sum_level_4: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_sum_level_3 = '1' then
                    for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/8+1-1) loop
                        gaussian_sum_level_4_r(i) <= gaussian_sum_level_4(i);
                    end loop;
                else
                    gaussian_sum_level_4_r <= (others => (others => '0'));
                end if;
            end if;
        end if;
    end process reg_gaussian_sum_level_4;

    -- level 5
    gaussian_sum_level_5(GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/16) <= '0'&gaussian_sum_level_4_r(GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/8);
    gen_gaussian_l5: for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/16-1) generate
        gaussian_sum_level_5(i) <= ('0'&gaussian_sum_level_4_r(i*2))+('0'&gaussian_sum_level_4_r(i*2+1));
    end generate gen_gaussian_l5;

    reg_gaussian_sum_level_5: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_sum_level_4 = '1' then
                    for i in 0 to (GAUSSIAN_NUM_LINES*GAUSSIAN_LINE_SIZE/16+1-1) loop
                        gaussian_sum_level_5_r(i) <= gaussian_sum_level_5(i);
                    end loop;
                else
                    gaussian_sum_level_5_r <= (others => (others => '0'));
                end if;
            end if;
        end if;
    end process reg_gaussian_sum_level_5;

    -- level 6
    gaussian_sum_level_6(0) <= gaussian_sum_level_5_r(0)+gaussian_sum_level_5_r(1);
    gaussian_sum_level_6(1) <= gaussian_sum_level_5_r(2)+gaussian_sum_level_5_r(3);

    reg_gaussian_sum_level_6: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_sum_level_5 = '1' then
                    gaussian_sum_level_6_r(0) <= gaussian_sum_level_6(0);
                    gaussian_sum_level_6_r(1) <= gaussian_sum_level_6(1);
                else
                    gaussian_sum_level_6_r <= (others => (others => '0'));
                end if;
            end if;
        end if;
    end process reg_gaussian_sum_level_6;

    -- level 7
    gaussian_sum_level_7 <= gaussian_sum_level_6_r(0) + gaussian_sum_level_6_r(1);

    reg_gaussian_sum_level_7: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_sum_level_6 = '1' then
                    gaussian_sum_level_7_r <= gaussian_sum_level_7;
                else
                    gaussian_sum_level_7_r <= (others => '0');
                end if;
            end if;
        end if;
    end process reg_gaussian_sum_level_7;

    -- final shift (division by 4096)
    reg_gaussian_result: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_sum_level_7 = '1' then
                    gaussian_result <= gaussian_sum_level_7_r(ELEMENT_SIZE+12-1 downto 12);
                else
                    gaussian_result <= (others => '0');
                end if;
            end if;
        end if;
    end process reg_gaussian_result;


    line_buffers_orientation: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_gaussian= '1' then
                    sr_orientation(0)(0) <= gaussian_result;
                    for i in (orientation_sr_line_size-1) downto 1 loop
                        sr_orientation(0)(i) <= sr_orientation(0)(i-1);
                    end loop;
                    for line in 1 to ORIENTATION_NUM_LINES-1 loop
                        sr_orientation(line)(0) <= sr_orientation(line-1)(orientation_sr_line_size-1);
                        for i in (orientation_sr_line_size-1) downto 1 loop
                            sr_orientation(line)(i) <= sr_orientation(line)(i-1);
                        end loop;
                    end loop;
                end if;
                --pop_v <= sr_gaussian(GAUSSIAN_NUM_LINES-1)(LINE_SIZE-1);
            end if;
        end if;
    end process line_buffers_orientation;

    window_buf_orientation: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_gaussian= '1' then
                    for line in 0 to ORIENTATION_NUM_LINES-1 loop
                        wb_orientation(line)(ORIENTATION_LINE_SIZE -1) <= unsigned(sr_orientation(ORIENTATION_NUM_LINES-1-line)(orientation_sr_line_size-1));
                        column_in(line)<= unsigned(sr_orientation(ORIENTATION_NUM_LINES-1-line)(orientation_sr_line_size-1));
                        pix_out(line) <= std_logic_vector(sr_orientation(ORIENTATION_NUM_LINES-1-line)(orientation_sr_line_size-1));
                        for i in 0 to (ORIENTATION_LINE_SIZE-2) loop
                            wb_orientation(line)(i) <= wb_orientation(line)(i+1);
                        end loop;
                    end loop;
                end if;
            end if;
        end if;
    end process window_buf_orientation;

    orientation_position: process(clk)
    begin
        if (rising_edge(clk)) then
            if reset_n = '1' then
                if (active = '1') then
                    if orientation_counter >= (orientation_sr_line_size*(NUM_LINES-GAUSSIAN_NUM_LINES)+1) then
                        orientation_counter <= 1; --  Starting the orientation at 1 makes it be advanced by 1 clk cycle
                    else
                        if valid_gaussian= '1' then
                            orientation_counter <= orientation_counter + 1;
                        else
                            orientation_counter <= orientation_counter;
                        end if;
                    end if;

                    if orientation_started = '0' then -- Starts counter when window buffer is full
                        if orientation_counter > ORIENTATION_LINE_SIZE * orientation_sr_line_size then -- Last (+1) accounts for 1 clk cycle delay
                            orientation_started <= '1';
                            pos_orientation.y <= ORIENTATION_LINE_SIZE_MIDDLE;
                            pos_orientation.x <= -1;
                        end if;
                    else
                        if (orientation_counter >= (orientation_sr_line_size*(NUM_LINES-GAUSSIAN_NUM_LINES)+1)) then
                            orientation_started <= '0';
                        else
                            orientation_started <= orientation_started;
                        end if;

                        if valid_gaussian= '1' then
                            if (pos_orientation.x >= (orientation_sr_line_size - 1)) then
                                pos_orientation.y <= pos_orientation.y + 1;
                                pos_orientation.x <= 0;
                            else
                                pos_orientation.x <= pos_orientation.x + 1;
                            end if;
                        end if;
                    end if;

                    if (pos_orientation.y >= ORIENTATION_NUM_LINES_MIDDLE and
 pos_orientation.y < orientation_sr_num - ORIENTATION_NUM_LINES_MIDDLE and
 pos_orientation.x + 1 < orientation_sr_line_size and
 pos_orientation.x + 1 >= ORIENTATION_LINE_SIZE - 1 ) then
                        valid_orientation_delay(0) <= '1';
                    else
                        valid_orientation_delay(0) <= '0';
                    end if;

                    for i in valid_orientation_delay'high downto 1 loop
                        valid_orientation_delay(i) <= valid_orientation_delay(i-1);
                    end loop;
                    valid_orientation <= valid_orientation_delay(valid_orientation_delay'high);

                    pos_orientation_1.y <= pos_orientation.y+GAUSSIAN_NUM_LINES_MIDDLE;
                    pos_orientation_1.x <= pos_orientation.x+GAUSSIAN_LINE_SIZE_MIDDLE-ORIENTATION_LINE_SIZE_MIDDLE;
                    pos_orientation_2 <= pos_orientation_1;
                    pos_orientation_delay(0) <= pos_orientation_2;
                    for i in pos_orientation_delay'high downto 1 loop
                        pos_orientation_delay(i) <= pos_orientation_delay(i-1);
                    end loop;
                    pos_orientation_exit <= pos_orientation_delay(pos_orientation_delay'high);
                    pos_orientation_x <= std_logic_vector(to_unsigned(pos_orientation_delay(pos_orientation_delay'high).x, pos_orientation_x'length));
                    pos_orientation_y <= std_logic_vector(to_unsigned(pos_orientation_delay(pos_orientation_delay'high).y, pos_orientation_y'length));

                    valid_orientation_column <= orientation_started and valid_gaussian;
                    valid_column_sum_level_1 <= valid_orientation_column;
                    valid_column_sum_level_2 <= valid_column_sum_level_1;
                    valid_column_sum_level_3 <= valid_column_sum_level_2;
                    valid_column_sum_level_4 <= valid_column_sum_level_3;
                    valid_column_sum_level_5 <= valid_column_sum_level_4;
                    valid_column_in_sum <= valid_column_sum_level_5;

                    valid_y_moment_sum_level_1 <= valid_orientation_column;
                    valid_y_moment_sum_level_2 <= valid_y_moment_sum_level_1;
                    valid_y_moment_sum_level_3 <= valid_y_moment_sum_level_2;
                    valid_y_moment_sum_level_4 <= valid_y_moment_sum_level_3;
                    valid_y_moment_sum_level_5 <= valid_y_moment_sum_level_4;
                    valid_y_moment_sum_level_6 <= valid_y_moment_sum_level_5;
                    valid_y_moment_in_sum <= valid_y_moment_sum_level_6;

                    y_moment_started <= orientation_started and (y_moment_started or valid_y_moment_in_sum);
                end if;
            else
                orientation_counter <= 1;
                orientation_started <= '0';
                y_moment_started <= '0';
                pos_orientation<= (0,0);
                pos_orientation_1 <= (0,0);
                pos_orientation_2 <= (0,0);
                valid_orientation_column <= '0';
                --internal_pos_feature_y <= (others => '0');
                --internal_pos_feature_x <= (others => '0');

                -- valid_column_sum_level_1 <= '0';
                -- valid_column_sum_level_2 <= '0';
                -- valid_column_sum_level_3 <= '0';
                -- valid_column_sum_level_4 <= '0';
                -- valid_column_sum_level_5 <= '0';
                -- valid_column_in_sum <= '0';
            end if;
        end if;
    end process orientation_position;

    column_sum: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_orientation_column = '1' then
                    column_sum_level_1(ORIENTATION_NUM_LINES/2) <= '0'&column_in(ORIENTATION_NUM_LINES-1);
                    for i in 0 to (ORIENTATION_NUM_LINES/2-1) loop
                        column_sum_level_1(i) <= ('0'&column_in(i*2))+('0'&column_in(i*2+1));
                    end loop;
                    --else
                    --    column_sum_level_1 <= (others => (others => '0'));
                end if;
                if valid_column_sum_level_1 = '1' then
                    column_sum_level_2(ORIENTATION_NUM_LINES/4) <= '0'&column_sum_level_1(ORIENTATION_NUM_LINES/2);
                    for i in 0 to (ORIENTATION_NUM_LINES/4-1) loop
                        column_sum_level_2(i) <= ('0'&column_sum_level_1(i*2))+('0'&column_sum_level_1(i*2+1));
                    end loop;
                else
                    column_sum_level_2 <= (others => (others => '0'));
                end if;
                if valid_column_sum_level_2 = '1' then
                    for i in 0 to (ORIENTATION_NUM_LINES/8) loop
                        column_sum_level_3(i) <= ('0'&column_sum_level_2(i*2))+('0'&column_sum_level_2(i*2+1));
                    end loop;
                else
                    column_sum_level_3 <= (others => (others => '0'));
                end if;
                if valid_column_sum_level_3 = '1' then
                    column_sum_level_4(ORIENTATION_NUM_LINES/16) <= '0'&column_sum_level_3(ORIENTATION_NUM_LINES/8);
                    for i in 0 to (ORIENTATION_NUM_LINES/16-1) loop
                        column_sum_level_4(i) <= ('0'&column_sum_level_3(i*2))+('0'&column_sum_level_3(i*2+1));
                    end loop;
                else
                    column_sum_level_4 <= (others => (others => '0'));
                end if;
                if valid_column_sum_level_4 = '1' then
                    column_sum_level_5(0) <= ('0'&column_sum_level_4(0))+('0'&column_sum_level_4(1));
                    column_sum_level_5(1) <= '0'&column_sum_level_4(2);
                    --else
                    --    column_sum_level_5 <= (others => (others => '0'));
                end if;
                if valid_column_sum_level_5 = '1' then
                    column_in_sum <= ("00"&column_sum_level_5(0))+("00"&column_sum_level_5(1));
                    --else
                    --    column_in_sum <= (others => '0');
                end if;
            end if;
        end if;
    end process column_sum;

    y_moment_adder: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_orientation_column = '1' then
                    for i in 0 to (ORIENTATION_NUM_LINES-1) loop
                        y_moment_sum_level_1(i) <= signed('0'&column_in(i)) * to_signed((18-i),6);
                    end loop;
                else
                    y_moment_sum_level_1 <= (others => (others => '0'));
                end if;
                if valid_y_moment_sum_level_1 = '1' then
                    y_moment_sum_level_2(ORIENTATION_NUM_LINES/2) <= y_moment_sum_level_1(ORIENTATION_NUM_LINES-1);
                    for i in 0 to (ORIENTATION_NUM_LINES/2-1) loop
                        y_moment_sum_level_2(i) <= (y_moment_sum_level_1(i*2))+(y_moment_sum_level_1(i*2+1));
                    end loop;
                else
                    y_moment_sum_level_2 <= (others => (others => '0'));
                end if;
                if valid_y_moment_sum_level_2 = '1' then
                    -- Extends previous sum level in 1 bit considering 2s complement representation
                    y_moment_sum_level_3(ORIENTATION_NUM_LINES/4) <= y_moment_sum_level_2(ORIENTATION_NUM_LINES/2)(y_moment_sum_level_2(0)'high)&y_moment_sum_level_2(ORIENTATION_NUM_LINES/2);
                    for i in 0 to (ORIENTATION_NUM_LINES/4-1) loop
                        y_moment_sum_level_3(i) <= (y_moment_sum_level_2(i*2)(y_moment_sum_level_2(0)'high)&y_moment_sum_level_2(i*2))+(y_moment_sum_level_2(i*2+1)(y_moment_sum_level_2(0)'high)&y_moment_sum_level_2(i*2+1));
                    end loop;
                else
                    y_moment_sum_level_3 <= (others => (others => '0'));
                end if;
                if valid_y_moment_sum_level_3 = '1' then
                    for i in 0 to (ORIENTATION_NUM_LINES/8) loop
                        y_moment_sum_level_4(i) <= (y_moment_sum_level_3(i*2))+(y_moment_sum_level_3(i*2+1));
                    end loop;
                else
                    y_moment_sum_level_4 <= (others => (others => '0'));
                end if;
                if valid_y_moment_sum_level_4 = '1' then
                    -- Extends previous sum level in 1 bit considering 2s complement representation
                    y_moment_sum_level_5(ORIENTATION_NUM_LINES/16) <= y_moment_sum_level_4(ORIENTATION_NUM_LINES/8)(y_moment_sum_level_4(0)'high)&y_moment_sum_level_4(ORIENTATION_NUM_LINES/8);
                    for i in 0 to (ORIENTATION_NUM_LINES/16-1) loop
                        y_moment_sum_level_5(i) <= (y_moment_sum_level_4(i*2)(y_moment_sum_level_4(0)'high)&y_moment_sum_level_4(i*2))+(y_moment_sum_level_4(i*2+1)(y_moment_sum_level_4(0)'high)&y_moment_sum_level_4(i*2+1));
                    end loop;
                else
                    y_moment_sum_level_5 <= (others => (others => '0'));
                end if;
                if valid_y_moment_sum_level_5 = '1' then
                    y_moment_sum_level_6(0) <= (y_moment_sum_level_5(0))+(y_moment_sum_level_5(1));
                    y_moment_sum_level_6(1) <= y_moment_sum_level_5(2);
                else
                    y_moment_sum_level_6 <= (others => (others => '0'));
                end if;
                if valid_y_moment_sum_level_6 = '1' then
                    y_moment_sum <= (y_moment_sum_level_6(0))+(y_moment_sum_level_6(1));
                else
                    y_moment_sum <= (others => '0');
                end if;
            end if;
        end if;
    end process y_moment_adder;

    y_moment_delay: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                valid_y_moment_delay(0) <= valid_y_moment_in_sum;
                for i in valid_y_moment_delay'high downto 1 loop
                    valid_y_moment_delay(i) <= valid_y_moment_delay(i-1);
                end loop;
                if (valid_y_moment_in_sum = '1') then
                    y_moment_delay_sr(0) <= y_moment_sum;
                    for i in y_moment_delay_sr'high downto 1 loop
                        y_moment_delay_sr(i) <= y_moment_delay_sr(i-1);
                    end loop;
                else 
                    y_moment_delay_sr <= (others => (others => '0'));
                end if;
            end if;
        end if;
    end process y_moment_delay;

    column_sum_delay: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                valid_column_in_sum_delay(0) <= valid_column_in_sum;
                for i in valid_column_in_sum_delay'high downto 1 loop
                    valid_column_in_sum_delay(i) <= valid_column_in_sum_delay(i-1);
                end loop;
                if (valid_column_in_sum = '1') then
                    column_sum_delay_sr(0) <= column_in_sum;
                    for i in column_sum_delay_sr'high downto 1 loop
                        column_sum_delay_sr(i) <= column_sum_delay_sr(i-1);
                    end loop;
                else
                    column_sum_delay_sr <= (others =>(others => '0'));
                end if;
            end if;
        end if;
    end process column_sum_delay;

    compute_m00: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if (valid_column_in_sum = '1') then
                    m00_1 <= signed(std_logic_vector'("0000000"&std_logic_vector(column_in_sum))) - signed(std_logic_vector'("0000000"&std_logic_vector(column_sum_delay_sr(column_sum_delay_sr'high))));
                    m00 <= m00_1 + m00;
                    valid_m00_1 <= '1';
                else 
                    m00_1 <= (others => '0');
                    m00 <= (others => '0');
                    valid_m00_1 <= '0';
                end if;
                m00_delayed <= m00;
                valid_m00 <= valid_m00_1;
                valid_m00_delayed <= valid_m00;
            end if;
        end if;
    end process compute_m00;

    compute_m10: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if (valid_column_in_sum = '1') then
                    m10_1 <= signed(column_in_sum)* to_signed(-18, 6);                                      -- S(Cin)*(-18)
                    m10_aux_1 <= signed(column_sum_delay_sr(column_sum_delay_sr'high)) * to_signed(-19, 6); -- S(Cout)*(-19)
                    m10_2 <= (m10_1(m10_1'high)&m10_1) + (m10_aux_1(m10_aux_1'high)&m10_aux_1);             -- S(Cin)*(-18) + S(Cout)*(-19) + m00_n-1                              -- S(Cin)*(-18) + S(Cout)*(-19)
                    m10_3 <= (m10_2(m10_2'high)&m10_2) + m00_delayed;                       
                    if (valid_m00 = '1') then                                               
                        m10 <= m10_3 + m10;                                                                 -- S(Cin)*(-18) + S(Cout)*(-19) + m00_n-1 + m10_n-1
                    else
                        m10 <= (others => '0'); 
                    end if;
                else 
                    m10 <= (others => '0'); 
                    m10_1 <= (others => '0');        
                    m10_aux_1 <= (others => '0');    
                    m10_2 <= (others => '0');    
                    m10_3 <= (others => '0');   
                end if;
                m10_delayed <= m10;
                valid_m10 <= valid_m00_delayed;
            end if;
        end if;
    end process compute_m10;

    compute_m01: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if (valid_y_moment_in_sum = '1') then
                    -- m01(Cin) - m01(Cout) 
                    m01_2 <= to_signed(to_integer((y_moment_sum(y_moment_sum'high)&y_moment_sum) - (y_moment_delay_sr(y_moment_delay_sr'high)(y_moment_last_i)&y_moment_delay_sr(y_moment_delay_sr'high))),m01_2'length);
                    -- bit extension of m01_1
                    --for i in 0 to m01_1'high loop
                    --    m01_2(i) <= m01_1(i);
                    --end loop;
                    --for i in (m01_1'high + 1) to m01_2'high loop
                    --    m01_2(i) <= m01_1(m01_1'high);
                    --end loop;
                    -- m01(Cin) - m01(Cout) + m01_n-1
                    --if (y_moment_started = '1') then
                    m01_delay_1 <= m01_2 + m01_delay_1; -- Delay to match m10 timing
                    m01 <= m01_delay_1;
                    --else 
                    --    m01 <= (others => '0');
                    --end if;
                else 
                    m01 <= (others => '0');
                    m01_delay_1 <= (others => '0');
                    m01_2 <= (others => '0');
                end if;
            end if;
        end if;
    end process compute_m01;

    -- Symetric of m10 and m01
    symetric_m10_gen: for i in 0 to m10'high generate
        m10_n(i) <= not(std_logic(m10(i)));
    end generate symetric_m10_gen;
    symetric_m01_gen: for i in 0 to m01'high generate
        m01_n(i) <= not(std_logic(m01(i)));
    end generate symetric_m01_gen;

    check_quadrant: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if ( m10 > to_signed(0,m10'length)) then
                    quadrant_aux(1) <= '0'; -- x moment
                    m10_abs <= unsigned(m10);
                else
                    quadrant_aux(1) <= '1'; -- x moment
                    m10_abs <= unsigned(m10_n)+1; -- +1 is two finish the 2s complement
                end if;
                if ( m01 > to_signed(0,m01'length)) then
                    quadrant_aux(0) <= '1'; -- y moment
                    m01_abs <= unsigned(m01);
                else
                    quadrant_aux(0) <= '0'; -- y moment
                    m01_abs <= unsigned(m01_n)+1; -- +1 is two finish the 2s complement
                end if;

                case quadrant_aux is
                    when "00" =>
                        quadrant_s <= "10"; -- x<0 & y<0 -> Q3
                        -- quadrant   <= "10";
                    when "01" =>
                        quadrant_s <= "01"; -- x<0 & y>0 -> Q2
                        -- quadrant   <= "01";
                    when "10" =>
                        quadrant_s <= "11"; -- x>0 & y<0 -> Q4
                        -- quadrant   <= "11";
                    when "11" =>
                        quadrant_s <= "00"; -- x>0 & y>0 -> Q1
                        -- quadrant   <= "00";
                    when others =>
                        quadrant_s <= "00";
                        -- quadrant   <= "00";
                end case;

                quadrant_delayed <= quadrant_s;
                quadrant <= quadrant_delayed;
            end if;
        end if;
    end process check_quadrant;

    -- Multiply by tangent
    tan_calc_1 <= '0'&std_logic_vector(m10_abs)&"00";
    tan_calc_2 <= '0'&std_logic_vector(m10_abs)&"00";
    tan_calc_3 <= signed(tan_calc_1) - signed(std_logic_vector'("000"&std_logic_vector(m10_abs)));
    tan_calc_4 <= signed(tan_calc_2) + signed(std_logic_vector'("000"&std_logic_vector(m10_abs)));
    tan_calc_5 <= '0'&std_logic_vector(m10_abs)&"0000";
    tan_calc_6 <= tan_calc_3&"0000";
    tan_result_2 <= "00"&tan_calc_4 + signed(tan_calc_5);
    tan_result_3 <= tan_calc_6 - signed(std_logic_vector'("0000000"&std_logic_vector(m10_abs)));
    tan_result_1 <= signed(std_logic_vector'(std_logic_vector(tan_calc_3)&'0'));
    tan_result_4 <= signed(std_logic_vector'(std_logic_vector(tan_calc_4)&"00000"));

    reg_tan_results: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                tan_result_1_r_int <= unsigned(tan_result_1(tan_result_1'high downto 5)); -- Removes the fractional part
                tan_result_2_r_int <= unsigned(tan_result_2(tan_result_2'high downto 5)); -- Removes the fractional part
                tan_result_3_r_int <= unsigned(tan_result_3(tan_result_3'high downto 5)); -- Removes the fractional part
                tan_result_4_r_int <= unsigned(tan_result_4(tan_result_4'high downto 5)); -- Removes the fractional part
                m01_abs_delayed <= m01_abs;
            end if;
        end if;
    end process reg_tan_results;

    tan_compare(0) <= '1' when tan_result_1_r_int > m01_abs_delayed else
                      '0';
    tan_compare(1) <= '1' when tan_result_2_r_int > m01_abs_delayed else
                      '0';
    tan_compare(2) <= '1' when tan_result_3_r_int > m01_abs_delayed else
                      '0';
    tan_compare(3) <= '1' when tan_result_4_r_int > m01_abs_delayed else
                      '0';

    reg_tan_compare: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                tan_compare_r <= tan_compare;
            end if;
        end if;
    end process reg_tan_compare;

    theta_priority_encoder: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                theta <="00" when tan_compare_r(0) = '1' else
                        "01" when tan_compare_r(1) = '1' else
                        "10" when tan_compare_r(2) = '1' else
                        "11" when tan_compare_r(3) = '1' else
                        "11";
            end if;
        end if;
    end process theta_priority_encoder;

end Behavioral;

