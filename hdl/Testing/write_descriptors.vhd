----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 05/08/2024 12:44:30 PM
-- Module Name: write_descriptors - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity write_descriptors is
    generic (
        MEM_SIZE : integer := 4096;
        THETA_SIZE : integer := 3
    );
    Port ( 
        clk : in STD_LOGIC;
        rst_n : in STD_LOGIC;
        en : in STD_LOGIC;
        descriptor : in STD_LOGIC_VECTOR(255 downto 0);
        pos_y : in STD_LOGIC_VECTOR(10 downto 0);
        pos_x : in STD_LOGIC_VECTOR(10 downto 0);
        score : in STD_LOGIC_VECTOR(11 downto 0);
        angle : in STD_LOGIC_VECTOR(THETA_SIZE+2-1 downto 0);
        scale : in STD_LOGIC;
        addr : out STD_LOGIC_VECTOR(31 downto 0);
        addr_128b : out STD_LOGIC_VECTOR(31 downto 0);
        d0 : out STD_LOGIC_VECTOR(31 downto 0);
        d1 : out STD_LOGIC_VECTOR(31 downto 0);
        d2 : out STD_LOGIC_VECTOR(31 downto 0);
        d3 : out STD_LOGIC_VECTOR(31 downto 0);
        d4 : out STD_LOGIC_VECTOR(31 downto 0);
        d5 : out STD_LOGIC_VECTOR(31 downto 0);
        d6 : out STD_LOGIC_VECTOR(31 downto 0);
        d7 : out STD_LOGIC_VECTOR(31 downto 0);
        pos_line : out STD_LOGIC_VECTOR(31 downto 0);
        scr_angle_line : out STD_LOGIC_VECTOR(31 downto 0)
    );
end write_descriptors;

architecture rtl of write_descriptors is
    signal s_addr : integer range 0 to MEM_SIZE-1;
    signal s_addr_128 : integer range 0 to MEM_SIZE*4-1;
    signal s_prev_en : std_logic := '0';

begin
    d0 <= descriptor(31 downto 0);
    d1 <= descriptor(63 downto 32);
    d2 <= descriptor(95 downto 64);
    d3 <= descriptor(127 downto 96);
    d4 <= descriptor(159 downto 128);
    d5 <= descriptor(191 downto 160);
    d6 <= descriptor(223 downto 192);
    d7 <= descriptor(255 downto 224);
    pos_line <= "00000"&pos_y&"00000"&pos_x;
    scr_angle_line <= "0"&scale&"00"&score&std_logic_vector(to_unsigned(0,16-angle'length))&angle;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '1' then
                if en = '1' and s_prev_en = '0' and s_addr <  (MEM_SIZE-1) then
                    s_addr <= s_addr + 4;
                    s_addr_128 <= s_addr_128 + 16;
                else
                    s_addr <= s_addr;
                    s_addr_128 <= s_addr_128;
                end if;
            else
                s_addr <= 0;
                s_addr_128 <= 0;
            end if;

            addr <= std_logic_vector(to_unsigned(s_addr, addr'length));
            addr_128b <= std_logic_vector(to_unsigned(s_addr_128, addr_128b'length));
            s_prev_en <= en;
        end if;
    end process;

end rtl;
