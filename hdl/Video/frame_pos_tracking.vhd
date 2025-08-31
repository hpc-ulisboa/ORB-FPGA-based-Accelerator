library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frame_pos_tracking is
    generic (
        H_RES: integer := 1920;
        V_RES: integer := 1080
    );
    port (
        hsync       : in  std_logic;
        vsync       : in  std_logic;
        pix_clk     : in  std_logic;
        rst         : in  std_logic;
        pix         : in  std_logic_vector(23 downto 0);
        min_col     : in  std_logic_vector(11 downto 0);
        max_col     : in  std_logic_vector(11 downto 0);
        min_row     : in  std_logic_vector(11 downto 0);
        max_row     : in  std_logic_vector(11 downto 0);
        pix_out     : out std_logic_vector(23 downto 0);
        pix_out_crs : out std_logic_vector(23 downto 0);
        pix_out_sqr : out std_logic_vector(23 downto 0);
        h_position_o: out std_logic_vector(11 downto 0);
        valid_pix   : out std_logic;
        frame_x_pos : out std_logic_vector(11 downto 0);
        frame_y_pos : out std_logic_vector(11 downto 0)
    );
end frame_pos_tracking;

architecture Behavioral of frame_pos_tracking is
    signal row        : unsigned(11 downto 0) := (others => '0');
    signal column     : unsigned(11 downto 0) := (others => '0');
    signal reset_sync : std_logic;
    signal hsync_prev : std_logic;
    signal vsync_prev : std_logic;
    signal s_frame_x_pos_min: signed(12 downto 0);
    signal s_frame_y_pos_min: signed(12 downto 0);
    signal s_frame_x_pos_max: signed(12 downto 0);
    signal s_frame_y_pos_max: signed(12 downto 0);
    constant horizontal_back_porch: natural := 55;
    constant vertical_back_porch  : natural := 42;
    constant max_x : natural := horizontal_back_porch + H_RES - 1;
    constant max_y : natural := vertical_back_porch + V_RES - 1;
    signal valid_x_pos: std_logic_vector(1 downto 0);
    signal valid_y_pos: std_logic_vector(1 downto 0);
    signal valid_pos : std_logic_vector(3 downto 0);
    signal s_frame_x_pos : unsigned(11 downto 0);
    signal s_frame_y_pos : unsigned(11 downto 0);
    signal started : std_logic := '0';
begin

    process(pix_clk)
    begin
        if rising_edge(pix_clk) then
            if vsync = '1' and vsync_prev = '0' then
                reset_sync <= '1';
                row        <= (others => '0');
                column     <= (others => '0');
            elsif hsync = '1' and hsync_prev = '0' then
                    row    <= row + 1;
                    column <= (others => '0');
            else
                column <= column + 1;
            end if;

            pix_out <= pix;
            
            hsync_prev <= hsync;
            vsync_prev <= vsync;
        end if;
    end process;

    process(pix_clk)
    begin
        if rising_edge(pix_clk) then
            if rst = '1' and vsync = '0' then
                started <= '0';
            elsif rst = '0' and vsync = '1' then
                started <= '1';
            elsif rst = '0' and vsync = '0' then
                started <= started;
            else
                started <= started;
            end if;
        end if;
    end process;

    s_frame_x_pos_min <= signed('0'&column)-to_signed(horizontal_back_porch,s_frame_x_pos_min'length);
    s_frame_y_pos_min <= signed('0'&row)-to_signed(vertical_back_porch,s_frame_y_pos_min'length);
    s_frame_x_pos_max <= to_signed(max_x,s_frame_x_pos_max'length)-signed('0'&column);
    s_frame_y_pos_max <= to_signed(max_y,s_frame_y_pos_max'length)-signed('0'&row);
    valid_x_pos <= s_frame_x_pos_min(s_frame_x_pos_min'high)&s_frame_x_pos_max(s_frame_x_pos_max'high);
    valid_y_pos <= s_frame_y_pos_min(s_frame_y_pos_min'high)&s_frame_y_pos_max(s_frame_y_pos_max'high);
    valid_pos <= valid_x_pos&valid_y_pos;
    -- Output white pixel if row and column are equal
    process(row, column, pix)
    begin
        if row >= unsigned(min_row) and row <= unsigned(max_row)  then
            pix_out_crs <= (others => '1');  -- White pixel
        elsif column >= unsigned(min_col) and column <= unsigned(max_col)  then
            pix_out_crs <= (others => '1');  -- White pixel
        else
            pix_out_crs <= pix;              -- Input pixel data
        end if;
        h_position_o <= std_logic_vector(column);

        case valid_pos is
            when "0000" =>
                frame_x_pos <= std_logic_vector(s_frame_x_pos_min(s_frame_x_pos_min'high-1 downto 0));
                s_frame_x_pos <= unsigned(s_frame_x_pos_min(s_frame_x_pos_min'high-1 downto 0));
                frame_y_pos <= std_logic_vector(s_frame_y_pos_min(s_frame_y_pos_min'high-1 downto 0));
                s_frame_y_pos <= unsigned(s_frame_y_pos_min(s_frame_y_pos_min'high-1 downto 0));
                case started is
                    when '1' =>
                        valid_pix <= '1';
                    when others =>
                        valid_pix <= '0';
                end case;
            when others =>
                frame_x_pos   <= (others => '0');
                s_frame_x_pos <= (others => '0');
                frame_y_pos   <= (others => '0');
                s_frame_y_pos <= (others => '0');
                valid_pix <= '0';
        end case;

        if valid_pos = "0000" then
            if s_frame_y_pos >= to_unsigned(230,s_frame_y_pos'length) and s_frame_y_pos <= to_unsigned(250,s_frame_y_pos'length) and s_frame_x_pos >= to_unsigned(310,s_frame_x_pos'length) and s_frame_x_pos <= to_unsigned(330,s_frame_x_pos'length) then
                pix_out_sqr <= x"FF0000"; -- White pixel
            elsif s_frame_x_pos = to_unsigned(1,s_frame_x_pos'length) then
                pix_out_sqr <= x"00FF00"; -- Blue pixel
            elsif s_frame_x_pos = to_unsigned(0,s_frame_x_pos'length) then
                pix_out_sqr <= x"0000FF"; -- Green pixel
            elsif s_frame_x_pos >= to_unsigned(H_RES-11,s_frame_x_pos'length) and s_frame_x_pos <= to_unsigned(H_RES-1,s_frame_x_pos'length) then
                pix_out_sqr <= x"0000FF"; -- Green pixel
            else
                pix_out_sqr <= pix;       -- Input pixel data
            end if;
        else
            pix_out_sqr <= pix;           -- Input pixel data
        end if;
        
    end process;

end Behavioral;
