----------------------------------------------------------------------------------
-- Company: INESC-ID
-- Engineer: Andre Costa [andre.mestre.costa@tecnico.ulisboa.pt]
-- 
-- Create Date: 04/12/2024 03:29:15 PM
-- Module Name: descriptor_construct - rtl
-- Project Name: ORB-Accelerator
-- Target Devices: NA
-- Tool Versions: NA
-- Description: 
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library intermodules_lib;
use intermodules_lib.intermodules_types.all;


entity descriptor_construct is
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
        ORIENTATION_LINE_SIZE_MIDDLE: integer := 18;
        WB_BRAM_NUM_LEVELS: integer := 3;
        THETA_SIZE: natural := 2
    );
    port (
        clk     : in std_logic;
        reset_n   : in std_logic;
        valid_orientation : in std_logic;
        pos_orientation_y : in std_logic_vector (10 downto 0);
        pos_orientation_x : in std_logic_vector (10 downto 0);
        quadrant : in std_logic_vector(1 downto 0);
        theta : in std_logic_vector(THETA_SIZE-1 downto 0);
        valid_pix_in : in std_logic;
        pix_in : in pix_array_t;
        start_constr : in std_logic;
        descriptor_ready : out std_logic;
        descriptor : out std_logic_vector(255 downto 0);
        pos_descriptor_y : out std_logic_vector (10 downto 0);
        pos_descriptor_x : out std_logic_vector (10 downto 0);
        constructor_ready : out std_logic;
        quadrant_o : out std_logic_vector(1 downto 0);
        theta_o : out std_logic_vector(THETA_SIZE-1 downto 0)
    );
end descriptor_construct;

architecture rtl of descriptor_construct is
    constant pix2orientation_delay : natural := 13;
    constant brief_pattern_size : natural := 256;
    constant brief_num_sections : natural := 46;
    constant brief_section_size : natural := 6;
    constant max_theta_i : unsigned(1 downto 0) := "11";
    constant constructor_delay : natural := brief_num_sections+5;
    constant num_brams_wb_level : natural := 4;

    type position_4bit_type is array (0 to 3) of unsigned(3 downto 0);
    type position_5bit_type is array (0 to 3) of unsigned(4 downto 0);
    type position_6bit_type is array (0 to 3) of unsigned(5 downto 0);
    type position_origin_pattern_type is array (0 to brief_section_size-1) of position_5bit_type;
    type position_rotate_pattern_type is array (0 to brief_section_size-1) of position_6bit_type;
    type partial_pattern_type is array (0 to brief_section_size-1) of position_4bit_type;
    type position_delay_type is array (0 to constructor_delay+1-1) of std_logic_vector(10 downto 0);
    type bram_64b_data_array_type is array (0 to 1) of std_logic_vector(63 downto 0);
    type bram_32b_data_array_type is array (0 to 1) of std_logic_vector(31 downto 0);
    type partial_bram_addr_array_type is array (0 to 1) of unsigned(9 downto 0);
    type bram_init_file_names_type is array (0 to 1) of string(1 to 30);

    type orientation_window_line_sr is array (0 to (pix2orientation_delay+2-1)) of std_logic_vector((ELEMENT_SIZE-1) downto 0);
    type orientation_window_sr is array (0 to (ORIENTATION_NUM_LINES-1)) of orientation_window_line_sr;
    type orientation_working_window_line_sr is array (0 to (ORIENTATION_LINE_SIZE-1)) of std_logic_vector((ELEMENT_SIZE-1) downto 0);
    type orientation_working_window_sr is array (0 to (brief_section_size-1)) of orientation_working_window_line_sr;
    type wb_bram_wen_array_type is array (0 to 1) of std_logic;
    type wb_bram_wen_col_array_type is array (0 to num_brams_wb_level-1) of wb_bram_wen_array_type;
    type wb_bram_wen_levels_array_type is array (0 to WB_BRAM_NUM_LEVELS-1) of wb_bram_wen_col_array_type;
    type wb_bram_en_array_type is array (0 to 1) of std_logic;
    type wb_bram_en_col_array_type is array (0 to num_brams_wb_level-1) of wb_bram_en_array_type;
    type wb_bram_en_levels_array_type is array (0 to WB_BRAM_NUM_LEVELS-1) of wb_bram_en_col_array_type;
    type wb_bram_addr_array_type is array (0 to 1) of std_logic_vector(6 downto 0);
    type wb_bram_addr_col_array_type is array (0 to num_brams_wb_level-1) of wb_bram_addr_array_type;
    type wb_bram_addr_levels_array_type is array (0 to WB_BRAM_NUM_LEVELS-1) of wb_bram_addr_col_array_type;
    type wb_bram_rd_addr_array_type is array (0 to WB_BRAM_NUM_LEVELS-1) of wb_bram_addr_array_type;
    type wb_bram_addr_calc_array_type is array (0 to 1) of unsigned(6+1 downto 0);
    type wb_bram_rd_addr_calc_array_type is array (0 to WB_BRAM_NUM_LEVELS-1) of wb_bram_addr_calc_array_type;
    type wb_bram_data_col_array_type is array (0 to num_brams_wb_level-1) of bram_32b_data_array_type;
    type wb_bram_data_levels_array_type is array (0 to WB_BRAM_NUM_LEVELS-1) of wb_bram_data_col_array_type;


    signal wb_orientation : orientation_window_sr := (others => (others => (others => '0')));
    signal wb_bram_en : std_logic := '1';
    signal wb_bram_wen : std_logic := '0';
    signal wb_bram_addr : wb_bram_addr_levels_array_type := (others => (others => (others => (others => '0'))));
    signal wb_bram_addr_wr : wb_bram_addr_array_type := (others => (others => '0'));
    signal wb_bram_addr_wr_r : wb_bram_addr_array_type := (others => (others => '0'));
    signal wb_bram_addr_rd : wb_bram_rd_addr_array_type := (others => (others => (others => '0')));
    signal wb_bram_addr_rd_1_lin : wb_bram_rd_addr_calc_array_type := (others => (others => (others => '0')));
    signal wb_bram_addr_rd_2_lin : wb_bram_rd_addr_calc_array_type := (others => (others => (others => '0')));
    signal wb_bram_addr_rd_1_col : wb_bram_rd_addr_calc_array_type := (others => (others => (others => '0')));
    signal wb_bram_addr_rd_2_col : wb_bram_rd_addr_calc_array_type := (others => (others => (others => '0')));
    signal wb_bram_addr_rd_1_circ : wb_bram_rd_addr_calc_array_type := (others => (others => (others => '0')));
    signal wb_bram_addr_rd_2_circ : wb_bram_rd_addr_calc_array_type := (others => (others => (others => '0')));
    signal wb_bram_addr_rd_1_r : wb_bram_rd_addr_calc_array_type := (others => (others => (others => '0')));
    signal wb_bram_addr_rd_2_r : wb_bram_rd_addr_calc_array_type := (others => (others => (others => '0')));
    signal wb_bram_data_i : wb_bram_data_col_array_type := (others => (others => (others => '0')));
    signal wb_bram_data_o : wb_bram_data_levels_array_type := (others => (others => (others => (others => '0'))));
    signal wb_column_index : unsigned(5 downto 0) := (others => '0');
    signal wb_column_index_s : unsigned(5 downto 0) := (others => '0');
    constant wb_brams_num_lines : natural := (32+16)*2;

    signal brief_pattern : position_origin_pattern_type := (others => (others => (others => '0')));
    signal brief_pattern_delay : position_origin_pattern_type := (others => (others => (others => '0')));
    signal brief_pattern_delay_2 : position_origin_pattern_type := (others => (others => (others => '0')));
    signal sink_0 : std_logic_vector (32-28-1 downto 0) := (others => '0');
    signal sink_1 : std_logic_vector (32-28-1 downto 0) := (others => '0');

    signal quadrant_r : unsigned(1 downto 0) := (others => '0');
    signal theta_r : unsigned(quadrant_r'high+THETA_SIZE  downto 0) := (others => '0');
    signal quadrant_x : unsigned(quadrant_r'high+THETA_SIZE downto 0) := (others => '0');
    signal sections_offset : unsigned(quadrant_x'high downto 0) := (others => '0');
    signal section_cntr : natural := 0;
    signal aux_cntr : natural := 0;

    signal theta_offset_a : unsigned(sections_offset'high+7 downto 0) := (others => '0');
    signal theta_offset_b : unsigned(sections_offset'high+7 downto 0) := (others => '0');

    signal partial_bram_addra   : unsigned(theta_offset_a'high downto 0) := (others => '0');
    signal partial_bram_addrb   : unsigned(theta_offset_b'high downto 0) := (others => '0');
    signal partial_bram_addra_r : unsigned(theta_offset_a'high downto 0) := (others => '0');
    signal partial_bram_addrb_r : unsigned(theta_offset_b'high downto 0) := (others => '0');

    signal accept_pix : std_logic := '1';
    signal constructor_finished : std_logic := '1';

    signal pixel_toggle : std_logic := '0';
    signal pix2compare_1 : pix2compare_type := (others => (others => '0'));
    signal pix2compare_2 : pix2compare_type := (others => (others => '0'));
    signal pix2compare_1_r : pix2compare_type := (others => (others => '0'));
    signal pix2compare_2_r : pix2compare_type := (others => (others => '0'));
    signal pix2compare_result_r : std_logic_vector(0 to brief_section_size-1) := (others => '0');
    signal brief_set_bitmask : std_logic_vector(255 downto 0) := (others => '0');

    signal work_window_1 : orientation_working_window_sr := (others => (others => (others => '0')));
    signal work_window_2 : orientation_working_window_sr := (others => (others => (others => '0')));
    signal work_window_1_r : orientation_working_window_sr := (others => (others => (others => '0')));
    signal work_window_2_r : orientation_working_window_sr := (others => (others => (others => '0')));

    signal pos_delay_x : position_delay_type := (others => (others => '0'));
    signal pos_delay_y : position_delay_type := (others => (others => '0'));

    signal descriptor_internal : std_logic_vector(255 downto 0) := (others => '0');
    signal descriptor_internal_r : std_logic_vector(255 downto 0) := (others => '0');
    signal cos_theta   : unsigned(2 downto 0) := (others => '0');
    signal sin_theta   : unsigned(2 downto 0) := (others => '0');
    signal cos_theta_r : unsigned(2 downto 0) := (others => '0');
    signal sin_theta_r : unsigned(2 downto 0) := (others => '0');

    type bram_addr_array_type is array (0 to 1) of std_logic_vector(partial_bram_addra'high downto 0);

    constant bram_data_width : integer := 32;
    constant bram_data_depth : integer := integer'((2**THETA_SIZE)*4*86);
    constant num_brams: integer := 2;
    constant bram_wea : std_logic := '0';
    constant bram_web : std_logic := '0';
    signal bram_ena   : std_logic := '1';
    signal bram_enb   : std_logic := '1';
    signal bram_addra : bram_addr_array_type := (others => (others => '0'));
    signal bram_addrb : bram_addr_array_type := (others => (others => '0'));
    signal bram_dia   : bram_32b_data_array_type := (others => (others => '0'));
    signal bram_dib   : bram_32b_data_array_type := (others => (others => '0'));
    signal bram_doa   : bram_32b_data_array_type := (others => (others => '0'));
    signal bram_dob   : bram_32b_data_array_type := (others => (others => '0'));

    constant bram_init_file : bram_init_file_names_type := (
        "BRIEF_pattern_bram0_8_sec.data",
        "BRIEF_pattern_bram1_8_sec.data"
    );
    --bram_init_files/
    --bram_init_files/

    component rams_sp_rom0_4_sec
        port(
            clk : in std_logic;
            enA : in std_logic;
            enB : in std_logic;
            addrA : in std_logic_vector(10 downto 0);
            addrB : in std_logic_vector(10 downto 0);
            doA : out std_logic_vector(31 downto 0);
            doB : out std_logic_vector(31 downto 0)
        );
    end component;
    component rams_sp_rom1_4_sec
        port(
            clk : in std_logic;
            enA : in std_logic;
            enB : in std_logic;
            addrA : in std_logic_vector(10 downto 0);
            addrB : in std_logic_vector(10 downto 0);
            doA : out std_logic_vector(31 downto 0);
            doB : out std_logic_vector(31 downto 0)
        );
    end component;
    component rams_sp_rom0_8_sec
        port(
            clk : in std_logic;
            enA : in std_logic;
            enB : in std_logic;
            addrA : in std_logic_vector(11 downto 0);
            addrB : in std_logic_vector(11 downto 0);
            doA : out std_logic_vector(31 downto 0);
            doB : out std_logic_vector(31 downto 0)
        );
    end component;
    component rams_sp_rom1_8_sec
        port(
            clk : in std_logic;
            enA : in std_logic;
            enB : in std_logic;
            addrA : in std_logic_vector(11 downto 0);
            addrB : in std_logic_vector(11 downto 0);
            doA : out std_logic_vector(31 downto 0);
            doB : out std_logic_vector(31 downto 0)
        );
    end component;
    component rams_sp_rom0_16_sec
        port(
            clk : in std_logic;
            enA : in std_logic;
            enB : in std_logic;
            addrA : in std_logic_vector(12 downto 0);
            addrB : in std_logic_vector(12 downto 0);
            doA : out std_logic_vector(31 downto 0);
            doB : out std_logic_vector(31 downto 0)
        );
    end component;
    component rams_sp_rom1_16_sec
        port(
            clk : in std_logic;
            enA : in std_logic;
            enB : in std_logic;
            addrA : in std_logic_vector(12 downto 0);
            addrB : in std_logic_vector(12 downto 0);
            doA : out std_logic_vector(31 downto 0);
            doB : out std_logic_vector(31 downto 0)
        );
    end component;
    component rams_sp_rom0_32_sec
        port(
            clk : in std_logic;
            enA : in std_logic;
            enB : in std_logic;
            addrA : in std_logic_vector(13 downto 0);
            addrB : in std_logic_vector(13 downto 0);
            doA : out std_logic_vector(31 downto 0);
            doB : out std_logic_vector(31 downto 0)
        );
    end component;
    component rams_sp_rom1_32_sec
        port(
            clk : in std_logic;
            enA : in std_logic;
            enB : in std_logic;
            addrA : in std_logic_vector(13 downto 0);
            addrB : in std_logic_vector(13 downto 0);
            doA : out std_logic_vector(31 downto 0);
            doB : out std_logic_vector(31 downto 0)
        );
    end component;

begin
    --gen_brief_brams: for i in 0 to num_brams-1 generate
    orientation_4_generate : if THETA_SIZE=2 generate
    bram_instance_0: rams_sp_rom0_4_sec
        port map (
            clk => clk,
            enA => bram_ena,
            enB => bram_enb,
            addrA => bram_addra(0),
            addrB => bram_addrb(0),
            doA => bram_doa(0),
            doB => bram_dob(0)
        );
    bram_instance_1: rams_sp_rom1_4_sec
        port map (
            clk => clk,
            enA => bram_ena,
            enB => bram_enb,
            addrA => bram_addra(1),
            addrB => bram_addrb(1),
            doA => bram_doa(1),
            doB => bram_dob(1)
        );
    end generate orientation_4_generate;
    orientation_8_generate : if THETA_SIZE=3 generate
    bram_instance_0: rams_sp_rom0_8_sec
        port map (
            clk => clk,
            enA => bram_ena,
            enB => bram_enb,
            addrA => bram_addra(0),
            addrB => bram_addrb(0),
            doA => bram_doa(0),
            doB => bram_dob(0)
        );
    bram_instance_1: rams_sp_rom1_8_sec
        port map (
            clk => clk,
            enA => bram_ena,
            enB => bram_enb,
            addrA => bram_addra(1),
            addrB => bram_addrb(1),
            doA => bram_doa(1),
            doB => bram_dob(1)
        );
    end generate orientation_8_generate;
    orientation_16_generate : if THETA_SIZE=4 generate
    bram_instance_0: rams_sp_rom0_16_sec
        port map (
            clk => clk,
            enA => bram_ena,
            enB => bram_enb,
            addrA => bram_addra(0),
            addrB => bram_addrb(0),
            doA => bram_doa(0),
            doB => bram_dob(0)
        );
    bram_instance_1: rams_sp_rom1_16_sec
        port map (
            clk => clk,
            enA => bram_ena,
            enB => bram_enb,
            addrA => bram_addra(1),
            addrB => bram_addrb(1),
            doA => bram_doa(1),
            doB => bram_dob(1)
        );
    end generate orientation_16_generate;
    orientation_32_generate : if THETA_SIZE=5 generate
    bram_instance_0: rams_sp_rom0_32_sec
        port map (
            clk => clk,
            enA => bram_ena,
            enB => bram_enb,
            addrA => bram_addra(0),
            addrB => bram_addrb(0),
            doA => bram_doa(0),
            doB => bram_dob(0)
        );
    bram_instance_1: rams_sp_rom1_32_sec
        port map (
            clk => clk,
            enA => bram_ena,
            enB => bram_enb,
            addrA => bram_addra(1),
            addrB => bram_addrb(1),
            doA => bram_doa(1),
            doB => bram_dob(1)
        );
    end generate orientation_32_generate;
    
    gen_wb_brams: for i in 0 to WB_BRAM_NUM_LEVELS-1 generate
        gen_wb_bram_levels: for j in 0 to num_brams_wb_level-1 generate
            wb_bram_instance: entity work.generic_bram_tdp
                generic map (
                    WIDTH_G => 32,
                    SIZE => wb_brams_num_lines,
                    ADDRWIDTH => 7
                )
                port map (
                    clkA => clk,
                    clkB => clk,
                    enB => wb_bram_en,
                    enA => wb_bram_en,
                    weA => wb_bram_wen,
                    weB => wb_bram_wen,
                    addrA => wb_bram_addr(i)(j)(0),
                    addrB => wb_bram_addr(i)(j)(1),
                    diA => wb_bram_data_i(j)(0),
                    diB => wb_bram_data_i(j)(1),
                    doA => wb_bram_data_o(i)(j)(0),
                    doB => wb_bram_data_o(i)(j)(1)
                );
        end generate gen_wb_bram_levels;
    end generate gen_wb_brams;

    wb_bram_wen <= accept_pix and valid_pix_in;

    wb_column_index_s <= wb_column_index+1;

    window_buf_orientation_bram: process(clk)
    begin
        if (rising_edge(clk)) then
            if (valid_pix_in = '1') then
                if (accept_pix = '1') then -- Only updates the window buffer when the constructor is not running
                    if (wb_column_index_s = wb_brams_num_lines/2) then
                        wb_column_index <= to_unsigned(0, wb_column_index'length);
                    else
                        wb_column_index <= wb_column_index_s;
                    end if;

                    for level in 0 to WB_BRAM_NUM_LEVELS-1 loop
                        for bram_i in 0 to num_brams_wb_level-1 loop
                            wb_bram_data_i(bram_i)(0) <= wb_orientation(bram_i*8  +3)(wb_orientation(0)'high)&wb_orientation(bram_i*8+1+3)(wb_orientation(0)'high)&wb_orientation(bram_i*8+2+3)(wb_orientation(0)'high)&wb_orientation(bram_i*8+3+3)(wb_orientation(0)'high);
                            wb_bram_data_i(bram_i)(1) <= wb_orientation(bram_i*8+4+3)(wb_orientation(0)'high)&wb_orientation(bram_i*8+5+3)(wb_orientation(0)'high)&wb_orientation(bram_i*8+6+3)(wb_orientation(0)'high)&wb_orientation(bram_i*8+7+3)(wb_orientation(0)'high);
                        end loop;
                        --wb_bram_data_i(4)(0) <= wb_orientation(32)(0)&wb_orientation(33)(0)&wb_orientation(34)(0)&wb_orientation(35)(0);
                        --wb_bram_data_i(4)(1) <= wb_orientation(36)(0)&x"000000";
                    end loop;
                end if;
                for line in 0 to pix_in'high loop
                    wb_orientation(line)(wb_orientation(line)'high) <= pix_in(line);
                    for i in 0 to (wb_orientation(line)'high-1) loop
                        wb_orientation(line)(i) <= wb_orientation(line)(i+1);
                    end loop;
                end loop;
            end if;
        end if;
    end process window_buf_orientation_bram;

    wb_bram_wr_addr_gen: for level in 0 to WB_BRAM_NUM_LEVELS-1 generate
        wb_bram_addr_level: for bram_i in 0 to num_brams_wb_level-1 generate
            wb_bram_addr_wr(0) <= std_logic_vector(unsigned(wb_column_index&'0'));--std_logic_vector(unsigned(wb_bram_addr_wr_r(0))+2);
            wb_bram_addr_wr(1) <= std_logic_vector(unsigned(wb_column_index&'1'));--std_logic_vector(unsigned(wb_bram_addr_wr_r(1))+2);
        end generate wb_bram_addr_level;
    end generate wb_bram_wr_addr_gen;

    wb_bram_addr_reg: process(clk)
    begin
        if (rising_edge(clk)) then
            for level in 0 to WB_BRAM_NUM_LEVELS-1 loop
                for bram_i in 0 to num_brams_wb_level-1 loop
                    case std_logic_vector'(reset_n&(accept_pix and valid_pix_in)) is
                        when "11" =>
                            wb_bram_addr(level)(bram_i)(0) <= wb_bram_addr_wr(0);
                            wb_bram_addr(level)(bram_i)(1) <= wb_bram_addr_wr(1);
                            wb_bram_addr_wr_r(0) <= wb_bram_addr_wr(0);
                            wb_bram_addr_wr_r(1) <= wb_bram_addr_wr(1);
                        when "10" =>
                            wb_bram_addr(level)(bram_i)(0) <= wb_bram_addr_rd(level)(0);
                            wb_bram_addr(level)(bram_i)(1) <= wb_bram_addr_rd(level)(1);
                            wb_bram_addr_wr_r(0) <= wb_bram_addr_wr_r(0);
                            wb_bram_addr_wr_r(1) <= wb_bram_addr_wr_r(1);
                        when others =>
                            wb_bram_addr(level)(bram_i)(0) <= "000"&x"0";
                            wb_bram_addr(level)(bram_i)(1) <= "000"&x"1";
                            --wb_bram_addr_wr_r(0) <= "00"&x"0";
                            --wb_bram_addr_wr_r(1) <= "00"&x"1";
                    end case;
                end loop;
            end loop;
        end if;
    end process wb_bram_addr_reg;

    partial_bram_addra <= unsigned(partial_bram_addra_r+to_unsigned(2,partial_bram_addra'length));
    partial_bram_addrb <= unsigned(partial_bram_addrb_r+to_unsigned(2,partial_bram_addrb'length));
    sections_offset <= quadrant_x+theta_r;
    theta_offset_a <= sections_offset*"1010110"; -- sections_offset*86
    theta_offset_b <= sections_offset*"1010110";  -- sections_offset*86

    bram_addr_reg: process(clk)
    begin
        if (rising_edge(clk)) then
            for i in num_brams-1 downto 0 loop
                if (constructor_finished = '0' and (section_cntr < (brief_num_sections-1))) then
                    if (aux_cntr = 1) then
                        bram_addra(i) <= std_logic_vector(partial_bram_addra);
                        bram_addrb(i) <= std_logic_vector(partial_bram_addrb);
                        partial_bram_addra_r <= partial_bram_addra;
                        partial_bram_addrb_r <= partial_bram_addrb;
                        section_cntr <= section_cntr + 1;
                        aux_cntr <= 0;
                    else 
                        aux_cntr <= aux_cntr + 1;
                    end if;
                else
                    bram_addra(i) <= std_logic_vector(unsigned'(to_unsigned(0, bram_addra(i)'length)+theta_offset_a));
                    bram_addrb(i) <= std_logic_vector(unsigned'(to_unsigned(1, bram_addra(i)'length)+theta_offset_b));
                    partial_bram_addra_r <= unsigned'(to_unsigned(0, partial_bram_addra_r'length)+theta_offset_a);
                    partial_bram_addrb_r <= unsigned'(to_unsigned(1, partial_bram_addrb_r'length)+theta_offset_b);
                    section_cntr <= 0;
                    aux_cntr <= 0;
                end if;
            end loop;
        end if;
    end process bram_addr_reg;

    constructor_supervisor: entity work.constructor_supervisor
    port map (
        clk => clk,
        reset_n => reset_n,
        brief_set_bitmask => brief_set_bitmask,
        descriptor_internal_r => descriptor_internal_r,
        accept_pix => accept_pix,
        descriptor => descriptor,
        constructor_ready => constructor_ready,
        start_constr => start_constr,
        constructor_finished => constructor_finished,
        pixel_toggle => pixel_toggle,
        descriptor_ready => descriptor_ready
    );

    update_trig_values: process(clk)
    begin
        if (rising_edge(clk)) then
            if (constructor_finished = '1') then
                theta_r    <= unsigned(std_logic_vector'(std_logic_vector(to_unsigned(0,quadrant_r'length))&theta));
                quadrant_r <= unsigned(quadrant);
                quadrant_x<= unsigned(std_logic_vector'(quadrant&std_logic_vector(to_unsigned(0,THETA_SIZE))));
            end if;
            if (constructor_finished = '0') then
                quadrant_o <= std_logic_vector(quadrant_r);
                theta_o    <= std_logic_vector(theta_r(theta'high downto 0));
            end if;
        end if;
    end process update_trig_values;
    
    -- Retrieves 6 coordinate pairs of the BRIEF pattern
    get_brief_brams: process(clk)
    begin
        if (rising_edge(clk)) then
            if reset_n = '1' then
                brief_pattern(0)(0) <= unsigned(bram_doa(0)(4 downto 0));
                brief_pattern(0)(1) <= unsigned(bram_doa(0)(9 downto 5));
                brief_pattern(0)(2) <= unsigned(bram_doa(0)(14 downto 10));
                brief_pattern(0)(3) <= unsigned(bram_doa(0)(19 downto 15));
                brief_pattern(1)(0) <= unsigned(bram_doa(0)(24 downto 20));
                brief_pattern(1)(1) <= unsigned(bram_doa(0)(29 downto 25));
                brief_pattern(1)(2) <= unsigned(std_logic_vector'(bram_dob(0)(2 downto 0)&bram_doa(0)(31 downto 30)));
                brief_pattern(1)(3) <= unsigned(bram_dob(0)(7 downto 3));
                brief_pattern(2)(0) <= unsigned(bram_dob(0)(12 downto 8));
                brief_pattern(2)(1) <= unsigned(bram_dob(0)(17 downto 13));
                brief_pattern(2)(2) <= unsigned(bram_dob(0)(22 downto 18));
                brief_pattern(2)(3) <= unsigned(bram_dob(0)(27 downto 23));
                brief_pattern(3)(0) <= unsigned(bram_doa(1)(4 downto 0));
                brief_pattern(3)(1) <= unsigned(bram_doa(1)(9 downto 5));
                brief_pattern(3)(2) <= unsigned(bram_doa(1)(14 downto 10));
                brief_pattern(3)(3) <= unsigned(bram_doa(1)(19 downto 15));
                brief_pattern(4)(0) <= unsigned(bram_doa(1)(24 downto 20));
                brief_pattern(4)(1) <= unsigned(bram_doa(1)(29 downto 25));
                brief_pattern(4)(2) <= unsigned(std_logic_vector'(bram_dob(1)(2 downto 0)&bram_doa(1)(31 downto 30)));
                brief_pattern(4)(3) <= unsigned(bram_dob(1)(7 downto 3));
                brief_pattern(5)(0) <= unsigned(bram_dob(1)(12 downto 8));
                brief_pattern(5)(1) <= unsigned(bram_dob(1)(17 downto 13));
                brief_pattern(5)(2) <= unsigned(bram_dob(1)(22 downto 18));
                brief_pattern(5)(3) <= unsigned(bram_dob(1)(27 downto 23));
                sink_0 <= bram_dob(0)(31 downto 28);
                sink_1 <= bram_dob(1)(31 downto 28);
                brief_pattern_delay <= brief_pattern;
                brief_pattern_delay_2 <= brief_pattern_delay;
            else
                --brief_pattern <= (others => (others => (others => '0')));
            end if;
        end if;
    end process get_brief_brams;

    -- get_pix2compare: process(clk)
    -- begin
    --     if (rising_edge(clk)) then
    --         for i in 0 to pix2compare_1'high loop
    --             pix2compare_1(i) <= '0'&wb_orientation(to_integer('0'&brief_pattern(i)(1)))(to_integer('0'&brief_pattern(i)(0)));
    --             pix2compare_2(i) <= '0'&wb_orientation(to_integer('0'&brief_pattern(i)(3)))(to_integer('0'&brief_pattern(i)(2)));
    --         end loop;
    --     end if;
    -- end process get_pix2compare;
    
    -- The "+ wb_column_index" compensates for the fact that the window rotates (wb_column_index is the "first" column of the patch)
    read_addr_gen: for i in 0 to WB_BRAM_NUM_LEVELS-1 generate
        wb_bram_addr_rd_1_col(i)(0) <= unsigned("00"&brief_pattern(i*2  )(1)&'0') + unsigned((wb_column_index)&'0');
        wb_bram_addr_rd_1_col(i)(1) <= unsigned("00"&brief_pattern(i*2+1)(1)&'0') + unsigned((wb_column_index)&'0');
        wb_bram_addr_rd_2_col(i)(0) <= unsigned("00"&brief_pattern(i*2  )(3)&'0') + unsigned((wb_column_index)&'0');
        wb_bram_addr_rd_2_col(i)(1) <= unsigned("00"&brief_pattern(i*2+1)(3)&'0') + unsigned((wb_column_index)&'0');
        
        wb_bram_addr_rd_1_lin(i)(0) <= unsigned("00"&brief_pattern(i*2  )(1)&'0') + unsigned((wb_column_index)&'0') + unsigned(std_logic_vector'( '0'&brief_pattern(i*2)(0)(2)))  ;
        wb_bram_addr_rd_1_lin(i)(1) <= unsigned("00"&brief_pattern(i*2+1)(1)&'0') + unsigned((wb_column_index)&'0') + unsigned(std_logic_vector'( '0'&brief_pattern(i*2+1)(0)(2)));
        wb_bram_addr_rd_2_lin(i)(0) <= unsigned("00"&brief_pattern(i*2  )(3)&'0') + unsigned((wb_column_index)&'0') + unsigned(std_logic_vector'( '0'&brief_pattern(i*2)(2)(2)))  ;
        wb_bram_addr_rd_2_lin(i)(1) <= unsigned("00"&brief_pattern(i*2+1)(3)&'0') + unsigned((wb_column_index)&'0') + unsigned(std_logic_vector'( '0'&brief_pattern(i*2+1)(2)(2)));
        wb_bram_addr_rd_1_circ(i)(0)<= unsigned(signed'(signed(wb_bram_addr_rd_1_lin(i)(0))-to_signed(wb_brams_num_lines,wb_bram_addr_rd_1_circ(i)(0)'length)));
        wb_bram_addr_rd_1_circ(i)(1)<= unsigned(signed'(signed(wb_bram_addr_rd_1_lin(i)(1))-to_signed(wb_brams_num_lines,wb_bram_addr_rd_1_circ(i)(1)'length)));
        wb_bram_addr_rd_2_circ(i)(0)<= unsigned(signed'(signed(wb_bram_addr_rd_2_lin(i)(0))-to_signed(wb_brams_num_lines,wb_bram_addr_rd_2_circ(i)(0)'length)));
        wb_bram_addr_rd_2_circ(i)(1)<= unsigned(signed'(signed(wb_bram_addr_rd_2_lin(i)(1))-to_signed(wb_brams_num_lines,wb_bram_addr_rd_2_circ(i)(1)'length)));
        
        wb_bram_addr_rd_1_r(i)(0) <= wb_bram_addr_rd_1_lin(i)(0) when unsigned(wb_bram_addr_rd_1_lin(i)(0)) < wb_brams_num_lines else wb_bram_addr_rd_1_circ(i)(0);
        wb_bram_addr_rd_1_r(i)(1) <= wb_bram_addr_rd_1_lin(i)(1) when unsigned(wb_bram_addr_rd_1_lin(i)(1)) < wb_brams_num_lines else wb_bram_addr_rd_1_circ(i)(1);
        wb_bram_addr_rd_2_r(i)(0) <= wb_bram_addr_rd_2_lin(i)(0) when unsigned(wb_bram_addr_rd_2_lin(i)(0)) < wb_brams_num_lines else wb_bram_addr_rd_2_circ(i)(0);
        wb_bram_addr_rd_2_r(i)(1) <= wb_bram_addr_rd_2_lin(i)(1) when unsigned(wb_bram_addr_rd_2_lin(i)(1)) < wb_brams_num_lines else wb_bram_addr_rd_2_circ(i)(1);

        wb_bram_addr_rd(i)(0) <= std_logic_vector(wb_bram_addr_rd_1_r(i)(0)(wb_bram_addr_rd_1_r(i)(0)'high-1 downto 0)) when pixel_toggle = '1' else std_logic_vector(wb_bram_addr_rd_2_r(i)(0)(wb_bram_addr_rd_2_r(i)(0)'high-1 downto 0));
        wb_bram_addr_rd(i)(1) <= std_logic_vector(wb_bram_addr_rd_1_r(i)(1)(wb_bram_addr_rd_1_r(i)(1)'high-1 downto 0)) when pixel_toggle = '1' else std_logic_vector(wb_bram_addr_rd_2_r(i)(1)(wb_bram_addr_rd_2_r(i)(1)'high-1 downto 0));
    end generate read_addr_gen;

    get_pix2compare: process(clk)
    begin
        if (rising_edge(clk)) then
            case brief_pattern_delay_2(0)(0)(1 downto 0) is
                when "00" =>
                    pix2compare_1(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(0)(4 downto 3)))(0)(31 downto 24);
                when "01" =>
                    pix2compare_1(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(0)(4 downto 3)))(0)(23 downto 16);
                when "10" =>
                    pix2compare_1(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(0)(4 downto 3)))(0)(15 downto 8);
                when "11" =>
                    pix2compare_1(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(0)(4 downto 3)))(0)(7 downto 0);
                when others =>
                    pix2compare_1(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(0)(4 downto 3)))(0)(7 downto 0);
            end case;
            case brief_pattern_delay_2(1)(0)(1 downto 0) is
                when "00" =>
                    pix2compare_1(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(0)(4 downto 3)))(1)(31 downto 24);
                when "01" =>
                    pix2compare_1(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(0)(4 downto 3)))(1)(23 downto 16);
                when "10" =>
                    pix2compare_1(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(0)(4 downto 3)))(1)(15 downto 8);
                when "11" =>
                    pix2compare_1(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(0)(4 downto 3)))(1)(7 downto 0);
                when others =>
                    pix2compare_1(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(0)(4 downto 3)))(1)(7 downto 0);
            end case;
            case brief_pattern_delay_2(2)(0)(1 downto 0) is
                when "00" =>
                    pix2compare_1(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(0)(4 downto 3)))(0)(31 downto 24);
                when "01" =>
                    pix2compare_1(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(0)(4 downto 3)))(0)(23 downto 16);
                when "10" =>
                    pix2compare_1(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(0)(4 downto 3)))(0)(15 downto 8);
                when "11" =>
                    pix2compare_1(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(0)(4 downto 3)))(0)(7 downto 0);
                when others =>
                    pix2compare_1(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(0)(4 downto 3)))(0)(7 downto 0);
            end case;
            case brief_pattern_delay_2(3)(0)(1 downto 0) is
                when "00" =>
                    pix2compare_1(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(0)(4 downto 3)))(1)(31 downto 24);
                when "01" =>
                    pix2compare_1(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(0)(4 downto 3)))(1)(23 downto 16);
                when "10" =>
                    pix2compare_1(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(0)(4 downto 3)))(1)(15 downto 8);
                when "11" =>
                    pix2compare_1(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(0)(4 downto 3)))(1)(7 downto 0);
                when others =>
                    pix2compare_1(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(0)(4 downto 3)))(1)(7 downto 0);
            end case;
            case brief_pattern_delay_2(4)(0)(1 downto 0) is
                when "00" =>
                    pix2compare_1(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(0)(4 downto 3)))(0)(31 downto 24);
                when "01" =>
                    pix2compare_1(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(0)(4 downto 3)))(0)(23 downto 16);
                when "10" =>
                    pix2compare_1(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(0)(4 downto 3)))(0)(15 downto 8);
                when "11" =>
                    pix2compare_1(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(0)(4 downto 3)))(0)(7 downto 0);
                when others =>
                    pix2compare_1(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(0)(4 downto 3)))(0)(7 downto 0);
            end case;
            case brief_pattern_delay_2(5)(0)(1 downto 0) is
                when "00" =>
                    pix2compare_1(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(0)(4 downto 3)))(1)(31 downto 24);
                when "01" =>
                    pix2compare_1(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(0)(4 downto 3)))(1)(23 downto 16);
                when "10" =>
                    pix2compare_1(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(0)(4 downto 3)))(1)(15 downto 8);
                when "11" =>
                    pix2compare_1(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(0)(4 downto 3)))(1)(7 downto 0);
                when others =>
                    pix2compare_1(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(0)(4 downto 3)))(1)(7 downto 0);
            end case;

            case brief_pattern_delay_2(0)(2)(1 downto 0) is
                when "00" =>
                    pix2compare_2(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(2)(4 downto 3)))(0)(31 downto 24);
                when "01" =>
                    pix2compare_2(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(2)(4 downto 3)))(0)(23 downto 16);
                when "10" =>
                    pix2compare_2(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(2)(4 downto 3)))(0)(15 downto 8);
                when "11" =>
                    pix2compare_2(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(2)(4 downto 3)))(0)(7 downto 0);
                when others =>
                    pix2compare_2(0) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(0)(2)(4 downto 3)))(0)(7 downto 0);
            end case;
            case brief_pattern_delay_2(1)(2)(1 downto 0) is
                when "00" =>
                    pix2compare_2(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(2)(4 downto 3)))(1)(31 downto 24);
                when "01" =>
                    pix2compare_2(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(2)(4 downto 3)))(1)(23 downto 16);
                when "10" =>
                    pix2compare_2(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(2)(4 downto 3)))(1)(15 downto 8);
                when "11" =>
                    pix2compare_2(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(2)(4 downto 3)))(1)(7 downto 0);
                when others =>
                    pix2compare_2(1) <= '0'&wb_bram_data_o(0)(to_integer('0'&brief_pattern_delay_2(1)(2)(4 downto 3)))(1)(7 downto 0);
            end case;
            case brief_pattern_delay_2(2)(2)(1 downto 0) is
                when "00" =>
                    pix2compare_2(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(2)(4 downto 3)))(0)(31 downto 24);
                when "01" =>
                    pix2compare_2(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(2)(4 downto 3)))(0)(23 downto 16);
                when "10" =>
                    pix2compare_2(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(2)(4 downto 3)))(0)(15 downto 8);
                when "11" =>
                    pix2compare_2(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(2)(4 downto 3)))(0)(7 downto 0);
                when others =>
                    pix2compare_2(2) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(2)(2)(4 downto 3)))(0)(7 downto 0);
            end case;
            case brief_pattern_delay_2(3)(2)(1 downto 0) is
                when "00" =>
                    pix2compare_2(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(2)(4 downto 3)))(1)(31 downto 24);
                when "01" =>
                    pix2compare_2(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(2)(4 downto 3)))(1)(23 downto 16);
                when "10" =>
                    pix2compare_2(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(2)(4 downto 3)))(1)(15 downto 8);
                when "11" =>
                    pix2compare_2(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(2)(4 downto 3)))(1)(7 downto 0);
                when others =>
                    pix2compare_2(3) <= '0'&wb_bram_data_o(1)(to_integer('0'&brief_pattern_delay_2(3)(2)(4 downto 3)))(1)(7 downto 0);
            end case;
            case brief_pattern_delay_2(4)(2)(1 downto 0) is
                when "00" =>
                    pix2compare_2(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(2)(4 downto 3)))(0)(31 downto 24);
                when "01" =>
                    pix2compare_2(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(2)(4 downto 3)))(0)(23 downto 16);
                when "10" =>
                    pix2compare_2(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(2)(4 downto 3)))(0)(15 downto 8);
                when "11" =>
                    pix2compare_2(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(2)(4 downto 3)))(0)(7 downto 0);
                when others =>
                    pix2compare_2(4) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(4)(2)(4 downto 3)))(0)(7 downto 0);
            end case;
            case brief_pattern_delay_2(5)(2)(1 downto 0) is
                when "00" =>
                    pix2compare_2(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(2)(4 downto 3)))(1)(31 downto 24);
                when "01" =>
                    pix2compare_2(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(2)(4 downto 3)))(1)(23 downto 16);
                when "10" =>
                    pix2compare_2(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(2)(4 downto 3)))(1)(15 downto 8);
                when "11" =>
                    pix2compare_2(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(2)(4 downto 3)))(1)(7 downto 0);
                when others =>
                    pix2compare_2(5) <= '0'&wb_bram_data_o(2)(to_integer('0'&brief_pattern_delay_2(5)(2)(4 downto 3)))(1)(7 downto 0);
            end case;
        end if;
    end process get_pix2compare;

    pix2compare_reg: process(clk)
    begin
        if (rising_edge(clk)) then
            for i in 0 to pix2compare_1'high loop
                pix2compare_1_r(i) <= pix2compare_1(i) when pixel_toggle = '0' else pix2compare_1_r(i);
                pix2compare_2_r(i) <= pix2compare_2(i) when pixel_toggle = '1' else pix2compare_2_r(i);
            end loop;
        end if;
    end process pix2compare_reg;

    brief_binnary_tests: entity work.brief_binnary_tests
        port map (
            clk => clk,
            reset_n => reset_n,
            pix2compare_1 => pix2compare_1_r,
            pix2compare_2 => pix2compare_2_r,
            pix2compare_result_r => pix2compare_result_r
        );
    

    compose_brief_0: entity work.compose_brief
        port map (
            clk => clk,
            reset_n => reset_n,
            brief_set_bitmask => brief_set_bitmask,
            pix2compare_result_r => pix2compare_result_r,
            descriptor_internal_r => descriptor_internal_r
        );

    delay_descriptor_pos: process(clk)
    begin
        if (rising_edge(clk)) then
            if (reset_n = '1') then
                if (constructor_finished = '1') then
                    pos_delay_x(0) <= pos_orientation_x;
                    pos_delay_y(0) <= pos_orientation_y;
                else
                    pos_delay_x(0) <= pos_delay_x(0);
                    pos_delay_y(0) <= pos_delay_y(0);
                end if;
                for i in pos_delay_x'high downto 1 loop
                    pos_delay_x(i) <= pos_delay_x(i-1);
                end loop;
                for i in pos_delay_y'high downto 1 loop
                    pos_delay_y(i) <= pos_delay_y(i-1);
                end loop;
                pos_descriptor_x <= pos_delay_x(pos_delay_x'high);
                pos_descriptor_y <= pos_delay_y(pos_delay_y'high);
            else
                pos_descriptor_x <= (others => '0');
                pos_descriptor_y <= (others => '0');
                pos_delay_x <= (others => (others => '0'));
                pos_delay_y <= (others => (others => '0'));
            end if;
        end if;
    end process delay_descriptor_pos;
end rtl;
