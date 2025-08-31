----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 02/23/2024 01:22:15 PM
-- Module Name: get_pix - behavioral
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity get_pix is
    generic (
        MEM_SIZE : integer := 1050 -- 30x35
    );
    port (
        clk: in std_logic;
        reset_n: in std_logic;
        pix_clk: in std_logic;
        data_in: in std_logic_vector (31 downto 0);
        addr: out std_logic_vector (31 downto 0);
        data_out: out std_logic_vector (31 downto 0);
        enb: out std_logic;
        mem_rst: out std_logic;
        wenb: out std_logic;
        fast_rst: out std_logic;
        pix_ready: out std_logic;
        pix_ready_n: out std_logic;
        pix_ready_1: out std_logic;
        pix: out std_logic_vector (7 downto 0)
    );
end get_pix;

architecture Behavioral of get_pix is
    signal value_buf : unsigned (31 downto 0) := (others => '0');
    signal value_out_buf : unsigned (31 downto 0);
    signal wenb_delay_1 : std_logic := '0';
    signal wenb_delay_2 : std_logic := '0';
    signal addr_s : unsigned (31 downto 0);
    signal mem_addr : unsigned (31 downto 0);
    signal valid_value : std_logic := '0';
    signal valid_value_delay : std_logic := '0';
    signal valid_value_delay_2 : std_logic := '0';
    signal state : integer := 0;
    signal pix_count : integer := 0;
    signal pix_array : std_logic_vector(23 downto 0);
    signal pix_index : integer := 1;
    signal line_read : std_logic := '0';
    signal start_stream : std_logic := '0';
    signal start_stream_delay : std_logic := '0';
    signal streaming_array : std_logic := '0';
    signal valid_control_bit : std_logic := '0';
    signal valid_pixel_read : std_logic := '0';
    signal valid_pixel_read_delay : std_logic := '0';
    signal valid_pixel_read_delay_2 : std_logic := '0';
    signal pix_ready_delay : std_logic := '0';
    signal valid_pix_array : std_logic := '0';
    signal finished_frame : std_logic := '0';
    signal enb_s : std_logic := '0';
    signal pix_array_saved : std_logic := '0';

begin

    bram_interaction: process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '1' then
                -- BRAM adress
                case state is
                    when 0 => addr <= (others => '0');
                    when 1 => addr <= std_logic_vector(mem_addr);
                    when 2 => addr <= (others => '0');
                    when others => addr <= (others => '0');
                end case;
                -- BRAM write enable
                case state is
                    when 0 => wenb <= '0';
                    when 1 => wenb <= '0';
                    when 2 => wenb <= '1';
                    when others => wenb <= '0';
                end case;
                -- BRAM read enable
                case state is
                    when 0 => enb <= '1';
                    when 1 => enb <= '1';
                    when 2 => enb <= '1';
                    when others => enb <= '0';
                end case;
                case state is
                    when 0 => enb_s <= '1';
                    when 1 => enb_s <= '1';
                    when 2 => enb_s <= '1';
                    when others => enb_s <= '0';
                end case;
            else
                addr <= (others => '0');
                wenb <= '0';
                enb <= '0';
                enb_s <= '0';
            end if;

            mem_rst <= '0';
            fast_rst <= '0';
            pix_ready_1 <= '0';
            data_out <= (others => '0');
        end if;
    end process bram_interaction;

    state_machine: process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '1' then
                if state = 0 then
                    if valid_control_bit = '1' then
                        if data_in(0) = '1' then
                            state <= 1;
                        else
                            state <= 0;
                        end if;
                    else
                        state <= 0;
                    end if;
                elsif state = 1 then
                    if pix_count = MEM_SIZE-1 then
                        state <= 2;
                    else
                        state <= 1;
                    end if;
                elsif state = 2 then
                    state <= 0;
                else
                    state <= state;
                end if;
            else
                state <= 0;
            end if;
        end if;
    end process state_machine;

    frame_available: process(clk)
    begin
        if rising_edge(clk) then
            if (reset_n = '1') then
                if start_stream = '0' and state = 0 and enb_s = '1' then
                    valid_control_bit <= '1';
                elsif state = 2 then
                    valid_control_bit <= '0';
                else
                    valid_control_bit <= '0';
                end if;
            else
                valid_control_bit <= '0';
            end if;
        end if;
    end process frame_available;

    read_frame: process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '1' then
                if state = 1  and pix_count < MEM_SIZE then
                    if start_stream = '0' then
                        mem_addr <= "0000000000000000000000000000" & "1000"; -- 8
                        valid_pixel_read_delay_2 <= '1';
                        start_stream_delay <= '1';
                        pix_array_saved <= '0';
                        pix_ready <= '0';
                        pix_ready_n <= '1';
                    else
                        if valid_pixel_read = '1' then
                            pix_array <= data_in(31 downto 8);
                            valid_pixel_read_delay_2 <= '0';
                            valid_pix_array <= '1';
                            pix_array_saved <= '1';
                        else
                            if pix_array_saved = '1' then
                                mem_addr <= mem_addr + 4;
                                valid_pixel_read_delay_2 <= '1';
                                pix_array_saved <= '0';
                            else
                                mem_addr <= mem_addr;
                                valid_pixel_read_delay_2 <= '0';
                                pix_array_saved <= pix_array_saved;
                            end if;
                        end if;

                        case pix_index is
                            when 0 => pix <= data_in(7 downto 0);
                            when 1 => pix <= pix_array(7 downto 0);
                            when 2 => pix <= pix_array(15 downto 8);
                            when 3 => pix <= pix_array(23 downto 16);
                            when others => pix <= (others => '0');
                        end case;

                        if valid_pix_array = '1' and pix_index < 3 then
                            pix_index <= pix_index + 1;
                            pix_ready <= '1';
                            pix_ready_n <= '0';
                        else
                            pix_index <= 0;
                        end if;
                        if valid_pix_array = '1' then 
                            pix_count <= pix_count + 1;
                        end if;
                    end if;
                elsif state = 2 then

                    pix_array <= (others => '0');
                    pix <= (others => '0');
                    pix_index <= 1;
                    pix_count <= 0;
                    valid_pix_array <= '0';
                    mem_addr <= (others => '0');
                    valid_pixel_read_delay_2 <= '0';
                    start_stream_delay <= '0';
                    pix_array_saved <= '0';
                    pix_ready <= '0';
                    pix_ready_n <= '1';
                else
                    pix_ready <= '0';
                    pix_ready_n <= '1';
                end if;
            else
                pix_array <= (others => '0');
                pix <= (others => '0');
                pix_index <= 1;
                pix_count <= 0;
                valid_pix_array <= '0';
                mem_addr <= (others => '0');
                valid_pixel_read_delay_2 <= '0';
                start_stream_delay <= '0';
                pix_array_saved <= '0';
                pix_ready <= '0';
                pix_ready_n <= '1';
            end if;
        end if;
    end process read_frame;

    update_delay_buff: process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '1' then
                valid_pixel_read <= valid_pixel_read_delay;
                valid_pixel_read_delay <= valid_pixel_read_delay_2;
                start_stream <= start_stream_delay;
            else
                valid_pixel_read <= '0';
                valid_pixel_read_delay <= '0';
                start_stream <= '0';
            end if;
        end if;
    end process;

end Behavioral;