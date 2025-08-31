----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 04/17/2024 03:21:51 PM
-- Module Name: fast_brief_coordinator - behavioral
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity fast_brief_coordinator is
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
        clk : in std_logic;
        rst_n : in std_logic;
        pos_feature_y : in std_logic_vector(10 downto 0);
        pos_feature_x : in std_logic_vector(10 downto 0);
        pos_orientation_y : in std_logic_vector(10 downto 0);
        pos_orientation_x : in std_logic_vector(10 downto 0);
        constructor_available : in std_logic;
        pop_feature : out std_logic;
        start_constructor : out std_logic
    );
end fast_brief_coordinator;

architecture Behavioral of fast_brief_coordinator is
    constant max_x : integer := LINE_SIZE-ORIENTATION_LINE_SIZE_MIDDLE-GAUSSIAN_LINE_SIZE_MIDDLE-1;
    constant min_x : integer := ORIENTATION_LINE_SIZE_MIDDLE+GAUSSIAN_LINE_SIZE_MIDDLE;
    constant max_y : integer := NUM_LINES-ORIENTATION_LINE_SIZE_MIDDLE-GAUSSIAN_LINE_SIZE_MIDDLE-3;
    constant min_y : integer := ORIENTATION_LINE_SIZE_MIDDLE+GAUSSIAN_LINE_SIZE_MIDDLE;
    signal pos_feature_x_int : integer := 0;
    signal pos_feature_y_int : integer := 0;
    signal s_pop_feature : std_logic := '0';
    signal s_pop_feature_delay : std_logic := '0';
begin

    pos_feature_x_int <= to_integer(unsigned(pos_feature_x));
    pos_feature_y_int <= to_integer(unsigned(pos_feature_y));
    
    process(clk)
    begin
        if (rising_edge(clk)) then
            if (rst_n='1') then
                if ((pos_feature_x=pos_orientation_x and pos_feature_y=pos_orientation_y) and not(pos_feature_x = "00000000000") and not(pos_feature_y = "00000000000")) then
                    if (constructor_available='1') then
                        start_constructor <= '1';
                    else
                        start_constructor <= '0';
                    end if;
                    pop_feature <= '1';
                    s_pop_feature <= '1';
                else
                    if (s_pop_feature='1') then
                        pop_feature <= '0';
                        s_pop_feature <= '0';
                    else
                        if ((pos_feature_x_int < min_x or pos_feature_x_int > max_x or pos_feature_y_int < min_y or pos_feature_y_int > max_y) and not(pos_feature_x = "00000000000") and not(pos_feature_y = "00000000000")) then
                            if (s_pop_feature_delay = '0') then
                                pop_feature <= '1';
                                s_pop_feature <= '1';
                            else
                                pop_feature <= '0';
                                s_pop_feature <= '0';
                            end if;
                        else
                            pop_feature <= '0';
                            s_pop_feature <= '0';
                        end if;
                    end if;
                    start_constructor <= '0';
                end if;
                s_pop_feature_delay <= s_pop_feature;
            else
                pop_feature <= '0';
                s_pop_feature <= '0';
                s_pop_feature_delay <= '0';
                start_constructor <= '0';
            end if;
        end if;
        
    end process;


end Behavioral;
