----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 03/01/2024 02:43:02 PM
-- Module Name: feature2bram - behavioral
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity feature2bram is
    generic (
        ELEMENT_SIZE    : integer := 8
    );
    port (
        clk : in std_logic;
        reset_n : in std_logic;
        ready : in std_logic;
        pos_y : in std_logic_vector (10 downto 0);
        pos_x : in std_logic_vector (10 downto 0);
        score : in std_logic_vector ((ELEMENT_SIZE+3) downto 0);
        addr : out std_logic_vector (31 downto 0);
        data_o : out std_logic_vector (31 downto 0);
        enb : out std_logic;
        mem_rst : out std_logic;
        wenb : out std_logic
    );
end feature2bram;

architecture Behavioral of feature2bram is
    signal base_addr : unsigned (31 downto 0) := (others => '0');
    signal ready_buff : std_logic := '0';
    signal pos_y_buff : std_logic_vector (10 downto 0) := (others => '0');
    signal pos_x_buff : std_logic_vector (10 downto 0) := (others => '0');
    signal score_buff : std_logic_vector ((ELEMENT_SIZE+3) downto 0) := (others => '0');
    signal index : integer := 0;
    signal wenb_delay : std_logic := '0';
    signal data_buff : std_logic_vector (31 downto 0);
begin

    new_feature: process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '1' then
                if (ready = '1' and ready_buff = '0') then
                    pos_y_buff <= pos_y;
                    pos_x_buff <= pos_x;
                    score_buff <= score;
                    base_addr <= base_addr + 4;
                    addr <= std_logic_vector(base_addr);
                end if;

                if ready_buff = '1' then
                    data_o <= score_buff & pos_x_buff(9 downto 0) & pos_y_buff(9 downto 0);
                    data_buff <= score_buff & pos_x_buff(9 downto 0) & pos_y_buff(9 downto 0);
                    wenb <= '1';
                else 
                    data_o <= data_buff;
                    wenb <= '0';
                end if;
            else
                pos_y_buff <= (others => '0');
                pos_x_buff <= (others => '0');
                score_buff <= (others => '0');
                base_addr <= (others => '0');
                addr <= (others => '0');
                data_o <= (others => '0');
                wenb <= '0';
            end if;
        end if;
    end process new_feature;

    update_buffers: process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '1' then
                ready_buff <= ready;
                enb <= '1';
            else
                ready_buff <= '0';
                enb <= '0';
            end if;
        end if;
    end process update_buffers;

end Behavioral;
