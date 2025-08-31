----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 02/09/2024 03:22:36 PM
-- Module Name: scalar - behavioral
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


entity scalar is
    generic (
        ELEMENT_SIZE    : integer := 8;
        LINE_SIZE       : integer := 35;
        NUM_LINES       : integer := 30
    );
    port (
        clk     : in std_logic;
        push_v  : in std_logic_vector((ELEMENT_SIZE-1) downto 0);
        active  : in std_logic;
        reset_n   : in std_logic;
        valid_pix_out : out std_logic;
        pix_out  : out std_logic_vector((ELEMENT_SIZE-1) downto 0)
    );
end scalar;

architecture Behavioral of scalar is
    constant SCALAR_NUM_LINES: integer := 1;
    constant SCALAR_NUM_LINES_MIDDLE: integer := 1;
    constant SCALAR_LINE_SIZE: integer := 2;
    constant SCALAR_LINE_SIZE_MIDDLE: integer := 1;
    type scalar_line_sr is array (0 to (LINE_SIZE+2-1)) of std_logic_vector((ELEMENT_SIZE-1) downto 0);
    type scalar_window_line_sr is array (0 to (SCALAR_LINE_SIZE-1)) of unsigned((ELEMENT_SIZE-1) downto 0);
    type scalar_window_sr is array (0 to (SCALAR_NUM_LINES-1)) of scalar_window_line_sr;
    type position_type is record
        x : integer;
        y : integer;
    end record;

    signal sr_scalar : scalar_line_sr := (others => (others => '0'));
    signal wb_scalar : scalar_window_sr := (others => (others => (others => '0')));
    signal window_sum : unsigned(ELEMENT_SIZE+2-1 downto 0) := (others => '0');
    signal pos_scalar : position_type := (0, 0);
    signal scalar_counter : integer := 1;
    signal scalar_started : std_logic := '0';
    signal nms_counter : integer := 1;
    signal nms_started : std_logic := '0';
    signal valid_scalar_window : std_logic := '0';
    signal x_value : std_logic_vector(10 downto 0) := (others => '0');
    signal y_value : std_logic_vector(10 downto 0) := (others => '0');
    signal x_even : std_logic := '0';
    signal y_even : std_logic := '0';
    signal pix_00 : unsigned(ELEMENT_SIZE+2-1 downto 0) := (others => '0');
    signal pix_01 : unsigned(ELEMENT_SIZE+2-1 downto 0) := (others => '0');
    signal pix_10 : unsigned(ELEMENT_SIZE+2-1 downto 0) := (others => '0');
    signal pix_11 : unsigned(ELEMENT_SIZE+2-1 downto 0) := (others => '0');



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

    line_buffers_scalar: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                sr_scalar(0) <= push_v;
                for i in sr_scalar'high downto 1 loop
                    sr_scalar(i) <= sr_scalar(i-1);
                end loop;
            end if;
        end if;
    end process line_buffers_scalar;

    x_value <= std_logic_vector(to_unsigned(pos_scalar.x, x_value'length));
    x_even  <= x_value(0);
    y_value <= std_logic_vector(to_unsigned(pos_scalar.y, y_value'length));
    y_even  <= y_value(0);
    
    scalar_position: process(clk)
    begin
        if (rising_edge(clk)) then
            if reset_n = '1' then
                if (active = '1') then
                    if scalar_counter >= (LINE_SIZE*NUM_LINES) then
                        scalar_counter <= 1; --  Starting the scalar at 1 makes it be advanced by 1 clk cycle
                    else
                        scalar_counter <= scalar_counter + 1;
                    end if;

                    if scalar_started = '0' then -- Starts counter when window buffer is full
                        if scalar_counter > LINE_SIZE then -- Last (+1) accounts for 1 clk cycle delay
                            scalar_started <= '1';
                            pos_scalar.y <= 1;
                            pos_scalar.x <= 0;
                        end if;
                    else
                        if (scalar_counter >= (LINE_SIZE*NUM_LINES)) then
                            scalar_started <= '0';
                        else
                            scalar_started <= scalar_started;
                        end if;
                        if (pos_scalar.x >= (LINE_SIZE - 1)) then
                            pos_scalar.y <= pos_scalar.y + 1;
                            pos_scalar.x <= 0;
                        else
                            pos_scalar.x <= pos_scalar.x + 1;
                        end if;
                    end if;

                    if (pos_scalar.y < NUM_LINES - 1 and pos_scalar.x < LINE_SIZE - 1 and
                        pos_scalar.x + 1 >= 1 and x_even = '0' and y_even = '1') then
                        valid_scalar_window <= '1';
                    else
                        valid_scalar_window <= '0';
                    end if;
                end if;
            else
                scalar_counter <= 1; --  Starting the scalar at 1 makes it be advanced by 1 clk cycle
                scalar_started <= '0';
                pos_scalar<=(0, 0);
            end if;
        end if;
    end process scalar_position;

    pix_00 <= unsigned(std_logic_vector'("00"&sr_scalar(sr_scalar'high)));
    pix_01 <= unsigned(std_logic_vector'("00"&sr_scalar(sr_scalar'high-1)));
    pix_10 <= unsigned(std_logic_vector'("00"&sr_scalar(1)));
    pix_11 <= unsigned(std_logic_vector'("00"&sr_scalar(0)));

    window_sum <= pix_00 + pix_01 + pix_10 + pix_11;

    check_circle: process(clk)
    begin
        if (rising_edge(clk)) then
            if (active = '1') then
                if valid_scalar_window = '1' then
                    pix_out <= std_logic_vector(window_sum(ELEMENT_SIZE+2-1 downto 2));
                else
                    pix_out <= (others => '0');
                end if;
                valid_pix_out <= valid_scalar_window;
            end if;
        end if;
    end process check_circle;

end Behavioral;