----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 03/05/2024 06:09:16 PM
-- Module Name: read_mem_bram - behavioral
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity read_mem_bram is
port (clk : in std_logic;
enb_i : in std_logic;
addr_i : in std_logic_vector(31 downto 0);
enb_o : out std_logic;
addr_o : out std_logic_vector(31 downto 0) );
end read_mem_bram;

architecture Behavioral of read_mem_bram is
    signal enb_buff_1 : std_logic := '0';
    signal enb_buff_2 : std_logic := '0';
    signal enb_buff_3 : std_logic := '0';
    signal enb_buff_4 : std_logic := '0';
    signal addr_buff_1 : std_logic_vector(31 downto 0) := (others => '0');
    signal addr_buff_2 : std_logic_vector(31 downto 0) := (others => '0');
    signal addr_buff_3 : std_logic_vector(31 downto 0) := (others => '0');
    signal addr_buff_4 : std_logic_vector(31 downto 0) := (others => '0');

begin
    process(clk) 
    begin
        if rising_edge(clk) then
            enb_buff_1  <= enb_i;
            enb_buff_2  <= enb_buff_1;
            enb_buff_3  <= enb_buff_2;
            enb_o       <= enb_buff_3;
            addr_buff_1 <= addr_i;
            addr_buff_2 <= addr_buff_1;
            addr_buff_3 <= addr_buff_2;
            addr_o      <= addr_buff_3;
        end if;
    end process;

end Behavioral;
