----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 05/08/2024 12:44:30 PM
-- Module Name: write_descriptor_bram - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity write_descriptor_bram is
    generic (
        MEM_SIZE : integer := 4096;
        THETA_SIZE : integer := 3
    );
    Port ( 
        clk : in STD_LOGIC;
        rst_n : in STD_LOGIC;
        we_i : in std_logic;
        descriptor : in STD_LOGIC_VECTOR(255 downto 0);
        addr : in STD_LOGIC_VECTOR(31 downto 0);
        we_o : out STD_LOGIC_VECTOR(3 downto 0);
        addr_o : out STD_LOGIC_VECTOR(31 downto 0);
        data_o_0 : out STD_LOGIC_VECTOR(31 downto 0);
        data_o_1 : out STD_LOGIC_VECTOR(31 downto 0)
    );
end write_descriptor_bram;

architecture rtl of write_descriptor_bram is
    signal data_o_0_0 : std_logic_vector(31 downto 0):=(others => '0');
    signal data_o_0_1 : std_logic_vector(31 downto 0):=(others => '0');
    signal data_o_0_2 : std_logic_vector(31 downto 0):=(others => '0');
    signal data_o_0_3 : std_logic_vector(31 downto 0):=(others => '0');

    signal data_o_1_0 : std_logic_vector(31 downto 0):=(others => '0');
    signal data_o_1_1 : std_logic_vector(31 downto 0):=(others => '0');
    signal data_o_1_2 : std_logic_vector(31 downto 0):=(others => '0');
    signal data_o_1_3 : std_logic_vector(31 downto 0):=(others => '0');

    signal cnt : natural := 0;
    signal addr_r : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '1' then
                if cnt = 0 then
                    if we_i = '1' then
                        cnt <= cnt + 1;
                        we_o <= (others => '1');
                        data_o_0 <= descriptor(31 downto 0);
                        data_o_1 <= descriptor(159 downto 128);
                        addr_r <= addr;
                        addr_o <= std_logic_vector(unsigned(addr) + to_unsigned(cnt*4,addr_o'length));
                        data_o_0_0 <= descriptor(31 downto 0);
                        data_o_0_1 <= descriptor(63 downto 32);
                        data_o_0_2 <= descriptor(95 downto 64);
                        data_o_0_3 <= descriptor(127 downto 96);
                        data_o_1_0 <= descriptor(159 downto 128);
                        data_o_1_1 <= descriptor(191 downto 160);
                        data_o_1_2 <= descriptor(223 downto 192);
                        data_o_1_3 <= descriptor(255 downto 224);
                    else
                        cnt <= 0;
                        we_o <= (others => '0');
                        data_o_0 <= (others => '0');
                        data_o_1 <= (others => '0');
                        addr_o <= (others => '0');
                        data_o_0_0 <= (others => '0');
                        data_o_0_1 <= (others => '0');
                        data_o_0_2 <= (others => '0');
                        data_o_0_3 <= (others => '0');
                        data_o_1_0 <= (others => '0');
                        data_o_1_1 <= (others => '0');
                        data_o_1_2 <= (others => '0');
                        data_o_1_3 <= (others => '0');
                    end if;
                elsif cnt = 1 then
                    cnt <= cnt + 1;
                    we_o <= (others => '1');
                    data_o_0 <= data_o_0_1;
                    data_o_1 <= data_o_1_1;
                    addr_o <= std_logic_vector(unsigned(addr_r) + to_unsigned(cnt*4,addr_o'length));
                elsif cnt = 2 then
                    cnt <= cnt + 1;
                    we_o <= (others => '1');
                    data_o_0 <= data_o_0_2;
                    data_o_1 <= data_o_1_2;
                    addr_o <= std_logic_vector(unsigned(addr_r) + to_unsigned(cnt*4,addr_o'length));
                elsif cnt = 3 then
                    cnt <= cnt + 1;
                    we_o <= (others => '1');
                    data_o_0 <= data_o_0_3;
                    data_o_1 <= data_o_1_3;
                    addr_o <= std_logic_vector(unsigned(addr_r) + to_unsigned(cnt*4,addr_o'length));
                elsif cnt = 4 then
                    cnt <= 0;
                    we_o <= (others => '0');
                    data_o_0 <= (others => '0');
                    data_o_1 <= (others => '0');
                    addr_o <= (others => '0');
                end if;
                    
            else
                addr_o   <= (others => '0');
                data_o_0 <= (others => '0');
                data_o_1 <= (others => '0');
                data_o_0_0 <= (others => '0');
                data_o_0_1 <= (others => '0');
                data_o_0_2 <= (others => '0');
                data_o_0_3 <= (others => '0');
                data_o_1_0 <= (others => '0');
                data_o_1_1 <= (others => '0');
                data_o_1_2 <= (others => '0');
                data_o_1_3 <= (others => '0');
            end if;
        end if;
    end process;

end rtl;
