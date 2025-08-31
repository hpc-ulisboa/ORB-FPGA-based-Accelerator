----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 04/17/2024 02:53:21 PM
-- Module Name: feature_fifo - behavioral
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY feature_fifo IS
    GENERIC (
        FIFO_SIZE : INTEGER := 128;
        ADDR_SIZE : INTEGER := 7;
        COORDINATE_SIZE : INTEGER := 11;
        SCORE_SIZE : INTEGER := 12
    );
    PORT (
        clk : IN STD_LOGIC;
        rst_n : IN STD_LOGIC;
        push_feature : IN STD_LOGIC;
        push_pos_feature_y : IN STD_LOGIC_VECTOR (COORDINATE_SIZE - 1 DOWNTO 0);
        push_pos_feature_x : IN STD_LOGIC_VECTOR (COORDINATE_SIZE - 1 DOWNTO 0);
        push_feature_score : IN STD_LOGIC_VECTOR (SCORE_SIZE - 1 DOWNTO 0);
        pop_feature : IN STD_LOGIC;
        pop_pos_feature_y : OUT STD_LOGIC_VECTOR (COORDINATE_SIZE - 1 DOWNTO 0);
        pop_pos_feature_x : OUT STD_LOGIC_VECTOR (COORDINATE_SIZE - 1 DOWNTO 0);
        pop_feature_score : OUT STD_LOGIC_VECTOR (SCORE_SIZE - 1 DOWNTO 0)
    );
END feature_fifo;

ARCHITECTURE Behavioral OF feature_fifo IS
    TYPE coord_fifo_type IS ARRAY (0 TO FIFO_SIZE - 1) OF STD_LOGIC_VECTOR(COORDINATE_SIZE - 1 DOWNTO 0);
    TYPE score_fifo_type IS ARRAY (0 TO FIFO_SIZE - 1) OF STD_LOGIC_VECTOR(SCORE_SIZE - 1 DOWNTO 0);
    SIGNAL pos_y_fifo : coord_fifo_type := (OTHERS => (OTHERS => '0'));
    SIGNAL pos_x_fifo : coord_fifo_type := (OTHERS => (OTHERS => '0'));
    SIGNAL score_fifo : score_fifo_type := (OTHERS => (OTHERS => '0'));
    SIGNAL push_ptr : unsigned((ADDR_SIZE - 1) DOWNTO 0) := (OTHERS => '0');
    SIGNAL pop_ptr : unsigned((ADDR_SIZE - 1) DOWNTO 0) := (OTHERS => '0');
    SIGNAL previous_push_feature : STD_LOGIC := '0';

BEGIN
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst_n = '1' THEN
                IF (push_feature = '1' AND previous_push_feature = '0' AND (push_ptr >= pop_ptr OR push_ptr <= pop_ptr-2)) THEN
                    pos_y_fifo(to_integer(push_ptr)) <= push_pos_feature_y;
                    pos_x_fifo(to_integer(push_ptr)) <= push_pos_feature_x;
                    score_fifo(to_integer(push_ptr)) <= push_feature_score;
                    push_ptr <= push_ptr + 1;
                END IF;
                IF pop_feature = '1' THEN
                    pop_ptr <= pop_ptr + 1;
                END IF;
                pop_pos_feature_y <= pos_y_fifo(to_integer(pop_ptr));
                pop_pos_feature_x <= pos_x_fifo(to_integer(pop_ptr));
                pop_feature_score <= score_fifo(to_integer(pop_ptr));
                previous_push_feature <= push_feature;
            ELSE
                push_ptr <= (OTHERS => '0');
                pop_ptr <= (OTHERS => '0');
                pos_y_fifo(0) <= (OTHERS => '0');
                pos_x_fifo(0) <= (OTHERS => '0');
                score_fifo(0) <= (OTHERS => '0');
                previous_push_feature <= '0';
            END IF;
        END IF;
    END PROCESS;

END Behavioral;