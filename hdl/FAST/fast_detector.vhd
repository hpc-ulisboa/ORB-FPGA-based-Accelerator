----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 02/09/2024 03:22:36 PM
-- Module Name: fast_detector - behavioral
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
use IEEE.STD_LOGIC_MISC.and_reduce;


entity fast_detector is
    generic (
        ELEMENT_SIZE    : integer := 8;
        LINE_SIZE       : integer := 35;
        NUM_LINES       : integer := 30;
        DETECTOR_NUM_LINES: integer := 7;
        DETECTOR_NUM_LINES_MIDDLE: integer := 3;
        DETECTOR_LINE_SIZE: integer := 7;
        DETECTOR_LINE_SIZE_MIDDLE: integer := 3;
        BRESENHAM_CIRCLE_SIZE : integer := 16;
        DIFF_THRESHOLD  : signed := "000001111";
        DIFF_THRESHOLD_N  : signed := "111110001";
        NMS_NUM_LINES: integer := 3;
        NMS_NUM_LINES_MIDDLE: integer := 1;
        NMS_LINE_SIZE: integer := 3;
        NMS_LINE_SIZE_MIDDLE: integer := 1
    );
    port (
        clk     : in std_logic;
        push_v  : in std_logic_vector((ELEMENT_SIZE-1) downto 0);
        active  : in std_logic;
        reset_n   : in std_logic;
        corner_thr : in std_logic_vector(8 downto 0);
        corner_thr_n : in std_logic_vector(8 downto 0);
        is_feature : out std_logic;
        pos_feature_y : out std_logic_vector (10 downto 0);
        pos_feature_x : out std_logic_vector (10 downto 0);
        feature_score : out std_logic_vector((ELEMENT_SIZE+3) downto 0)
    );
end fast_detector;

architecture Behavioral of fast_detector is
    type detector_line_sr is array (0 to (LINE_SIZE-1)) of std_logic_vector((ELEMENT_SIZE-1) downto 0);
    type detector_mult_line_sr is array (0 to (DETECTOR_NUM_LINES-1)) of detector_line_sr;
    type nms_line_sr is array (0 to ((LINE_SIZE-DETECTOR_LINE_SIZE+1)-1)) of unsigned((ELEMENT_SIZE+3) downto 0);
    type nms_mult_line_sr is array (0 to (NMS_NUM_LINES-1)) of nms_line_sr;
    type detector_window_line_sr is array (0 to (DETECTOR_LINE_SIZE-1)) of unsigned((ELEMENT_SIZE-1) downto 0);
    type detector_window_sr is array (0 to (DETECTOR_NUM_LINES-1)) of detector_window_line_sr;
    type nms_window_line_sr is array (0 to (NMS_LINE_SIZE-1)) of unsigned((ELEMENT_SIZE+3) downto 0);
    type nms_window_sr is array (0 to (NMS_NUM_LINES-1)) of nms_window_line_sr;
    type position_type is record
        x : integer;
        y : integer;
    end record;
    type circle_array_type is array (0 to BRESENHAM_CIRCLE_SIZE-1) of position_type;
    type circle_bitmask_array is array (0 to BRESENHAM_CIRCLE_SIZE-1) of std_logic_vector((BRESENHAM_CIRCLE_SIZE-1) downto 0);
    type difference_array_type is array (0 to BRESENHAM_CIRCLE_SIZE-1) of signed(ELEMENT_SIZE downto 0);
    type score_sum_level_1_type is array (0 to BRESENHAM_CIRCLE_SIZE/2) of unsigned(ELEMENT_SIZE downto 0);
    type score_sum_level_2_type is array (0 to BRESENHAM_CIRCLE_SIZE/4) of unsigned(ELEMENT_SIZE+1 downto 0);
    type score_sum_level_3_type is array (0 to BRESENHAM_CIRCLE_SIZE/8) of unsigned(ELEMENT_SIZE+2 downto 0);

    signal s_diff_threshold : signed(8 downto 0) := DIFF_THRESHOLD;
    signal s_diff_threshold_n : signed(8 downto 0) := DIFF_THRESHOLD_N;
    signal sr_detector : detector_mult_line_sr := (others => (others => (others => '0')));
    signal wb_detector : detector_window_sr := (others => (others => (others => '0')));
    signal sr_nms : nms_mult_line_sr := (others => (others => (others => '0')));
    signal wb_nms : nms_window_sr := (others => (others => (others => '0')));
    constant bresenham_circle : circle_array_type := (
        (0, 2), (0, 3), (0, 4), (1, 5), (2, 6), (3, 6), (4, 6), (5, 5),
        (6, 4), (6, 3), (6, 2), (5, 1), (4, 0), (3, 0), (2, 0), (1, 1)
    );
    constant circle_bitmasks : circle_bitmask_array := (
        "1111111110000000",
        "0111111111000000",
        "0011111111100000",
        "0001111111110000",
        "0000111111111000",
        "0000011111111100",
        "0000001111111110",
        "0000000111111111",
        "1000000011111111",
        "1100000001111111",
        "1110000000111111",
        "1111000000011111",
        "1111100000001111",
        "1111110000000111",
        "1111111000000011",
        "1111111100000001"
    );
    signal difference_vector : difference_array_type := (others => (others => '0'));
    signal difference_vector_abs : difference_array_type := (others => (others => '0'));
    signal score_sum_level_1 : score_sum_level_1_type := (others => (others => '0'));
    signal score_sum_level_2 : score_sum_level_2_type := (others => (others => '0'));
    signal score_sum_level_3 : score_sum_level_3_type := (others => (others => '0'));
    signal score : unsigned(ELEMENT_SIZE+3 downto 0) := (others => '0');
    signal is_brighter : std_logic_vector ((BRESENHAM_CIRCLE_SIZE-1) downto 0) :=  (others => '0');
    signal is_darker : std_logic_vector ((BRESENHAM_CIRCLE_SIZE-1) downto 0) :=  (others => '0');
    signal consecutive_brighter : circle_bitmask_array := (others => (others => '0'));
    signal consecutive_darker : circle_bitmask_array := (others => (others => '0'));
    signal result_brighter_vector : std_logic_vector ((BRESENHAM_CIRCLE_SIZE-1) downto 0) :=  (others => '0');
    signal result_darker_vector : std_logic_vector ((BRESENHAM_CIRCLE_SIZE-1) downto 0) :=  (others => '0');
    signal result_brighter : std_logic := '0';
    signal result_darker : std_logic := '0';
    signal pos_detector : position_type := (0, 0);
    signal pos_detector_1 : position_type := (0, 0);
    signal pos_detector_2 : position_type := (0, 0);
    signal pos_detector_3 : position_type := (0, 0);
    signal pos_detector_4 : position_type := (0, 0);
    signal pos_detector_5 : position_type := (0, 0);
    signal pos_corner : position_type := (0, 0);
    signal pos_nms : position_type := (0, 0);
    signal pos_nms_1 : position_type := (0, 0);
    signal pos_nms_2 : position_type := (0, 0);
    signal detector_counter : integer := 1;
    signal detector_started : std_logic := '0';
    signal nms_counter : integer := 1;
    signal nms_started : std_logic := '0';
    signal valid_detector_window : std_logic := '0';
    signal valid_difference_vector : std_logic := '0';
    signal valid_is_darker_brighter : std_logic := '0';
    signal valid_consecutive_darker_brighter : std_logic := '0';
    signal valid_result_vector : std_logic := '0';
    signal valid_results : std_logic := '0';
    signal valid_is_corner : std_logic := '0';
    signal valid_score : std_logic := '0';
    signal valid_nms_window : std_logic := '0';
    signal valid_nms_check_vector : std_logic := '0';
    signal valid_nms_check : std_logic := '0';
    signal is_corner: std_logic;
    signal score_out: unsigned(ELEMENT_SIZE+3 downto 0) := (others => '0');
    signal center_score: unsigned(ELEMENT_SIZE+3 downto 0) := (others => '0');
    signal center_score_1: unsigned(ELEMENT_SIZE+3 downto 0) := (others => '0');
    constant nms_sr_line_size: integer := (LINE_SIZE-DETECTOR_LINE_SIZE+1);
    signal nms_check_vector : std_logic_vector (7 downto 0) := (others => '0');
    signal nms_check : std_logic := '0';
    signal internal_is_feature : std_logic := '0';
    signal internal_pos_feature_y : std_logic_vector (10 downto 0) := (others => '0');
    signal internal_pos_feature_x : std_logic_vector (10 downto 0) := (others => '0');
    signal internal_feature_score : std_logic_vector ((ELEMENT_SIZE+3) downto 0) := (others => '0');
    signal internal_1_is_feature : std_logic := '0';
    signal internal_1_pos_feature_y : std_logic_vector (10 downto 0) := (others => '0');
    signal internal_1_pos_feature_x : std_logic_vector (10 downto 0) := (others => '0');
    signal internal_1_feature_score : std_logic_vector ((ELEMENT_SIZE+3) downto 0) := (others => '0');



    function or_reduce( V: std_logic_vector )
    return std_ulogic is
        variable result: std_ulogic;
    begin
        for i in V'range loop
            if i = V'left then
                result := V(i);
            else
                result := result OR V(i);
            end if;
            exit when result = '1';
        end loop;
        return result;
    end or_reduce;

begin
    -- Parameter config ----
    ------------------------
    process(clk)
    begin
        if (rising_edge(clk)) then
            s_diff_threshold <= signed(corner_thr);
            s_diff_threshold_n <= signed(corner_thr_n);
        end if;
    end process;
    ------------------------

    line_buffers_detector: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                sr_detector(0)(0) <= push_v;
                for i in (LINE_SIZE-1) downto 1 loop
                    sr_detector(0)(i) <= sr_detector(0)(i-1);
                end loop;
                for line in 1 to DETECTOR_NUM_LINES-1 loop
                    sr_detector(line)(0) <= sr_detector(line-1)(LINE_SIZE-1);
                    for i in (LINE_SIZE-1) downto 1 loop
                        sr_detector(line)(i) <= sr_detector(line)(i-1);
                    end loop;
                end loop;
                --pop_v <= sr_detector(DETECTOR_NUM_LINES-1)(LINE_SIZE-1);
            end if;
        end if;
    end process line_buffers_detector;

    window_buf_detector: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                for line in 0 to DETECTOR_NUM_LINES-1 loop
                    wb_detector(line)(DETECTOR_LINE_SIZE -1) <= unsigned(sr_detector(DETECTOR_NUM_LINES-1-line)(LINE_SIZE-1));
                    for i in 0 to (DETECTOR_LINE_SIZE-2) loop
                        wb_detector(line)(i) <= wb_detector(line)(i+1);
                    end loop;
                end loop;
            end if;
        end if;

    end process window_buf_detector;

    detector_position: process(clk)
    begin
        if (rising_edge(clk)) then
            if reset_n = '1' then
                if (active = '1') then
                    if detector_counter >= (LINE_SIZE*NUM_LINES) then
                        detector_counter <= 1; --  Starting the detector at 1 makes it be advanced by 1 clk cycle
                    else
                        detector_counter <= detector_counter + 1;
                    end if;

                    if detector_started = '0' then -- Starts counter when window buffer is full
                        if detector_counter > DETECTOR_LINE_SIZE * (LINE_SIZE + 1) - 1 - DETECTOR_LINE_SIZE_MIDDLE then -- Last (+1) accounts for 1 clk cycle delay
                            detector_started <= '1';
                            pos_detector.y <= DETECTOR_LINE_SIZE_MIDDLE;
                            pos_detector.x <= 0;
                        end if;
                    else
                        if (detector_counter >= (LINE_SIZE*NUM_LINES)) then
                            detector_started <= '0';
                        else
                            detector_started <= detector_started;
                        end if;
                        if (pos_detector.x >= (LINE_SIZE - 1)) then
                            pos_detector.y <= pos_detector.y + 1;
                            pos_detector.x <= 0;
                        else
                            pos_detector.x <= pos_detector.x + 1;
                        end if;
                    end if;

                    if (pos_detector.y >= DETECTOR_NUM_LINES_MIDDLE and
                        pos_detector.y < NUM_LINES - DETECTOR_NUM_LINES_MIDDLE and
                        pos_detector.x + 1 < LINE_SIZE - DETECTOR_LINE_SIZE_MIDDLE and
                        pos_detector.x + 1>= DETECTOR_LINE_SIZE_MIDDLE) then
                        valid_detector_window <= '1';
                    else
                        valid_detector_window <= '0';
                    end if;

                    valid_difference_vector <= valid_detector_window;
                    valid_is_darker_brighter <= valid_difference_vector;
                    valid_consecutive_darker_brighter <= valid_is_darker_brighter;
                    valid_result_vector <= valid_consecutive_darker_brighter;
                    valid_results <= valid_result_vector;
                    valid_is_corner <= valid_results;
                    valid_score <= valid_is_corner;

                    pos_detector_1 <= pos_detector;
                    pos_detector_2 <= pos_detector_1;
                    pos_detector_3 <= pos_detector_2;
                    pos_detector_4 <= pos_detector_3;
                    pos_detector_5 <= pos_detector_4;
                    pos_corner <= pos_detector_5;
                end if;
            else
                detector_counter <= 1; --  Starting the detector at 1 makes it be advanced by 1 clk cycle
                detector_started <= '0';
                pos_detector<=(0, 0);

                valid_difference_vector <= '0';
                valid_is_darker_brighter <= '0';
                valid_consecutive_darker_brighter <= '0';
                valid_result_vector <= '0';
                valid_results <= '0';
                valid_is_corner <='0';
                valid_score <='0';
                valid_detector_window <= '0';

                pos_detector_1 <= (0, 0);
                pos_detector_2 <= (0, 0);
                pos_detector_3 <= (0, 0);
                pos_detector_4 <= (0, 0);
                pos_detector_5 <= (0, 0);
                pos_corner <= (0, 0);
            end if;
        end if;
    end process detector_position;

    check_circle: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_detector_window = '1' then
                    for i in 0 to BRESENHAM_CIRCLE_SIZE-1 loop
                        difference_vector(i) <= ('0' & signed(wb_detector(3)(3)) - ('0' & signed(wb_detector(bresenham_circle(i).x)(bresenham_circle(i).y))));
                    end loop;
                else
                    difference_vector <= (others => (others => '0'));
                end if;

                if valid_difference_vector = '1' then
                    for i in 0 to BRESENHAM_CIRCLE_SIZE-1 loop
                        if difference_vector(i) > s_diff_threshold then
                            is_darker(i) <= '1';
                        else
                            is_darker(i) <= '0';
                        end if;
                        if difference_vector(i) < s_diff_threshold_n then
                            is_brighter(i) <= '1';
                        else
                            is_brighter(i) <= '0';
                        end if;
                    end loop;
                else
                    is_darker <= (others => '0');
                    is_brighter <= (others => '0');
                end if;

                if valid_is_darker_brighter = '1' then
                    for i in 0 to BRESENHAM_CIRCLE_SIZE-1 loop
                        consecutive_brighter(i) <= is_brighter and circle_bitmasks(i);
                        consecutive_darker(i) <= is_darker and circle_bitmasks(i);
                    end loop;
                else
                    consecutive_brighter <= (others => (others => '0'));
                    consecutive_darker <= (others => (others => '0'));
                end if;

                if valid_consecutive_darker_brighter = '1' then
                    for i in 0 to BRESENHAM_CIRCLE_SIZE-1 loop
                        if consecutive_brighter(i) = circle_bitmasks(i) then
                            result_brighter_vector(i) <= '1';
                        else
                            result_brighter_vector(i) <= '0';
                        end if;
                        if consecutive_darker(i) = circle_bitmasks(i) then
                            result_darker_vector(i) <= '1';
                        else
                            result_darker_vector(i) <= '0';
                        end if;
                    end loop;
                else
                    result_brighter_vector <= (others => '0');
                    result_darker_vector <= (others => '0');
                end if;

                if valid_result_vector = '1' then
                    result_brighter <= or_reduce(result_brighter_vector);
                    result_darker <= or_reduce(result_darker_vector);
                else
                    result_brighter <= '0';
                    result_darker <= '0';
                end if;

                if valid_results = '1' then
                    if result_brighter = '1' or result_darker = '1' then
                        is_corner <= '1';
                    else
                        is_corner <= '0';
                    end if;
                else
                    is_corner <= '0';
                end if;
            end if;
        end if;
    end process check_circle;

    compute_score: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_difference_vector = '1' then
                    for i in 0 to BRESENHAM_CIRCLE_SIZE-1 loop
                        if difference_vector(i) >= 0 then
                            difference_vector_abs(i) <= difference_vector(i);
                        else
                            difference_vector_abs(i) <= -difference_vector(i);
                        end if;
                    end loop;
                else
                    difference_vector_abs <= (others => (others => '0'));
                end if;

                for i in 0 to BRESENHAM_CIRCLE_SIZE/2-1 loop
                    score_sum_level_1(i) <= unsigned(difference_vector_abs(i*2)) + unsigned(difference_vector_abs(i*2+1));
                end loop;
                for i in 0 to BRESENHAM_CIRCLE_SIZE/4-1 loop
                    score_sum_level_2(i) <= ('0' & score_sum_level_1(i*2)) + ('0' & score_sum_level_1(i*2+1));
                end loop;
                for i in 0 to BRESENHAM_CIRCLE_SIZE/8-1 loop
                    score_sum_level_3(i) <= ('0' & score_sum_level_2(i*2)) + ('0' & score_sum_level_2(i*2+1));
                end loop;

                score <= ('0' & score_sum_level_3(0)) + ('0' & score_sum_level_3(1));
                if is_corner = '1' then
                    score_out <= score;
                else
                    score_out <= (others => '0');
                end if;
            end if;
        end if;
    end process compute_score;


    line_buffers_nms: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_score = '1' then
                    sr_nms(0)(0) <= score_out;
                    for i in (nms_sr_line_size-1) downto 1 loop
                        sr_nms(0)(i) <= sr_nms(0)(i-1);
                    end loop;
                    for line in 1 to NMS_NUM_LINES-1 loop
                        sr_nms(line)(0) <= sr_nms(line-1)(nms_sr_line_size-1);
                        for i in (nms_sr_line_size-1) downto 1 loop
                            sr_nms(line)(i) <= sr_nms(line)(i-1);
                        end loop;
                    end loop;
                end if;
                --pop_v <= sr_detector(DETECTOR_NUM_LINES-1)(LINE_SIZE-1);
            end if;
        end if;
    end process line_buffers_nms;

    window_buf_nms: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_score = '1' then
                    for line in 0 to NMS_NUM_LINES-1 loop
                        wb_nms(line)(NMS_LINE_SIZE -1) <= unsigned(sr_nms(NMS_NUM_LINES-1-line)(nms_sr_line_size-1));
                        for i in 0 to (NMS_LINE_SIZE-2) loop
                            wb_nms(line)(i) <= wb_nms(line)(i+1);
                        end loop;
                    end loop;
                end if;
            end if;
        end if;

    end process window_buf_nms;

    nms_position: process(clk)
    begin
        if (rising_edge(clk)) then
            if reset_n = '1' then
                if (active = '1') then
                    if nms_counter >= (nms_sr_line_size*(NUM_LINES-DETECTOR_NUM_LINES)+1) then
                        nms_counter <= 1; --  Starting the nms at 1 makes it be advanced by 1 clk cycle
                    else
                        if valid_score = '1' then
                            nms_counter <= nms_counter + 1;
                        else
                            nms_counter <= nms_counter;
                        end if;
                    end if;

                    if nms_started = '0' then -- Starts counter when window buffer is full
                        if nms_counter > NMS_LINE_SIZE * (nms_sr_line_size + 1) - 1 - NMS_LINE_SIZE_MIDDLE then -- Last (+1) accounts for 1 clk cycle delay
                            nms_started <= '1';
                            pos_nms.y <= NMS_LINE_SIZE_MIDDLE;
                            pos_nms.x <= 0;
                        end if;
                    else
                        if (nms_counter >= (nms_sr_line_size*(NUM_LINES-DETECTOR_NUM_LINES)+1)) then
                            nms_started <= '0';
                        else
                            nms_started <= nms_started;
                        end if;

                        if valid_score = '1' then
                            if (pos_nms.x >= (nms_sr_line_size - 1)) then
                                pos_nms.y <= pos_nms.y + 1;
                                pos_nms.x <= 0;
                            else
                                pos_nms.x <= pos_nms.x + 1;
                            end if;
                        end if;
                    end if;

                    if (pos_nms.y >= NMS_NUM_LINES_MIDDLE and
                        pos_nms.y < NUM_LINES - NMS_NUM_LINES_MIDDLE and
                        pos_nms.x + 1 < nms_sr_line_size - NMS_LINE_SIZE_MIDDLE and
                        pos_nms.x + 1>= NMS_LINE_SIZE_MIDDLE) then
                        valid_nms_window <= '1';
                    else
                        valid_nms_window <= '0';
                    end if;

                    pos_nms_1.y <= pos_nms.y+DETECTOR_NUM_LINES_MIDDLE;
                    pos_nms_1.x <= pos_nms.x+DETECTOR_LINE_SIZE_MIDDLE;
                    pos_nms_2 <= pos_nms_1;
                    internal_pos_feature_y <= std_logic_vector(to_unsigned(pos_nms_2.y, internal_pos_feature_y'length));
                    internal_pos_feature_x <= std_logic_vector(to_unsigned(pos_nms_2.x, internal_pos_feature_x'length));
                end if;
            else
            nms_counter <= 1;
            nms_started <= '0';
            pos_nms<= (0,0);
            pos_nms_1 <= (0,0);
            pos_nms_2 <= (0,0);
            valid_nms_window <= '0';
            internal_pos_feature_y <= (others => '0');
            internal_pos_feature_x <= (others => '0');
            end if;
        end if;
    end process nms_position;

    check_nms: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_nms_window = '1' then
                    if (wb_nms(1)(1) > wb_nms(0)(0)) then
                        nms_check_vector(0) <= '1';
                    else
                        nms_check_vector(0) <= '0';
                    end if;

                    if (wb_nms(1)(1) > wb_nms(0)(1)) then
                        nms_check_vector(1) <= '1';
                    else
                        nms_check_vector(1) <= '0';
                    end if;

                    if (wb_nms(1)(1) > wb_nms(0)(2)) then
                        nms_check_vector(2) <= '1';
                    else
                        nms_check_vector(2) <= '0';
                    end if;

                    if (wb_nms(1)(1) > wb_nms(1)(0)) then
                        nms_check_vector(3) <= '1';
                    else
                        nms_check_vector(3) <= '0';
                    end if;

                    if (wb_nms(1)(1) > wb_nms(1)(2)) then
                        nms_check_vector(4) <= '1';
                    else
                        nms_check_vector(4) <= '0';
                    end if;

                    if (wb_nms(1)(1) > wb_nms(2)(0)) then
                        nms_check_vector(5) <= '1';
                    else
                        nms_check_vector(5) <= '0';
                    end if;

                    if (wb_nms(1)(1) > wb_nms(2)(1)) then
                        nms_check_vector(6) <= '1';
                    else
                        nms_check_vector(6) <= '0';
                    end if;

                    if (wb_nms(1)(1) > wb_nms(2)(2)) then
                        nms_check_vector(7) <= '1';
                    else
                        nms_check_vector(7) <= '0';
                    end if;
                else
                    nms_check_vector <= (others => '0');
                end if;

                nms_check <= and_reduce(nms_check_vector);

                internal_is_feature <= nms_check and valid_nms_check;
                center_score <= wb_nms(1)(1);
                center_score_1 <= center_score;
                internal_feature_score <= std_logic_vector(center_score_1);
                valid_nms_check_vector <= valid_nms_window;
                valid_nms_check <= valid_nms_check_vector;
            end if;
        end if;
    end process check_nms;

    report_feature: process(clk)
    begin
        if (rising_edge(clk)) then
            if internal_is_feature = '1' then
                is_feature <= '1';
                internal_1_is_feature <= internal_is_feature;
                pos_feature_y <= internal_pos_feature_y;
                pos_feature_x <= internal_pos_feature_x;
                feature_score <= internal_feature_score;
                internal_1_pos_feature_y <= internal_pos_feature_y;
                internal_1_pos_feature_x <= internal_pos_feature_x;
                internal_1_feature_score <= internal_feature_score;
            else
                is_feature <= internal_1_is_feature;
                internal_1_is_feature <= internal_is_feature;
                pos_feature_y <= internal_1_pos_feature_y;
                pos_feature_x <= internal_1_pos_feature_x;
                internal_1_pos_feature_y <= (others => '0');
                internal_1_pos_feature_x <= (others => '0');
                feature_score <= internal_1_feature_score;
                internal_1_feature_score <= (others => '0');
            end if;
        end if;
    end process report_feature;
end Behavioral;