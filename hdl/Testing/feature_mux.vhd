----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 07/18/2024 11:59:36 AM
-- Module Name: feature_mux - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity feature_mux is
    Port (clk : in std_logic;
          sel : in std_logic;
          i_feat_ready_0 : in std_logic;
          i_pos_y_0 : in std_logic_vector(10 downto 0);
          i_pos_x_0 : in std_logic_vector(10 downto 0);
          i_score_0 : in std_logic_vector(11 downto 0);
          i_feat_ready_1 : in std_logic;
          i_pos_y_1 : in std_logic_vector(10 downto 0);
          i_pos_x_1 : in std_logic_vector(10 downto 0);
          i_score_1 : in std_logic_vector(11 downto 0);
          feat_ready : out std_logic;
          pos_y : out std_logic_vector(10 downto 0);
          pos_x : out std_logic_vector(10 downto 0);
          score : out std_logic_vector(11 downto 0)
          );
end feature_mux;

architecture rtl of feature_mux is

begin

    process(sel,i_feat_ready_0,i_feat_ready_1,i_pos_x_0,i_pos_x_1,i_pos_y_0,i_pos_y_1,i_score_0,i_score_1)
    begin
        case (sel) is
            when '0' => feat_ready <= i_feat_ready_0;
            when '1' => feat_ready <= i_feat_ready_1;
            when others => feat_ready <= i_feat_ready_0;
        end case;
        
        case (sel) is
            when '0' => pos_x <= i_pos_x_0;
            when '1' => pos_x <= i_pos_x_1;
            when others => pos_x <= i_pos_x_0;
        end case;
        
        case (sel) is
            when '0' => pos_y <= i_pos_y_0;
            when '1' => pos_y <= i_pos_y_1;
            when others => pos_y <= i_pos_y_0;
        end case;
        
        case (sel) is
            when '0' => score <= i_score_0;
            when '1' => score <= i_score_1;
            when others => score <= i_score_0;
        end case;
    end process;


end rtl;
