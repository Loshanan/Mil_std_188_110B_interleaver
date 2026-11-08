library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_trx is 
    generic (
        g_bit_period : natural := 234       -- bit period in clk cycles: 27MHz clk, 115200 baud rate
    );
    port (
        i_clk       : in  std_logic;
        i_rstn      : in  std_logic;
        i_uart_rx   : in  std_logic;
        o_uart_tx   : out std_logic   := '1';
        o_rx_data   : out std_logic_vector(7 downto 0);
        o_rx_dval   : out std_logic;
        i_tx_data   : in  std_logic_vector(7 downto 0);
        i_tx_dval   : in  std_logic;
        o_tx_ready  : out std_logic
    );
end uart_trx;

architecture arc_uart_trx of uart_trx is 
    -- constants
    constant c_half_bit_period  : natural   := g_bit_period/2;
    --constant c_message          : string    := "INPAMALAR MAHALINGAM";

    -- types
    type t_uart_state is (S_IDLE, S_START_BIT, S_DATA_BIT, S_STOP_BIT);
    --type t_data_bytes is array(integer range <>) of std_logic_vector(7 downto 0);
    
    -- functions
    function f_clog2(num: natural) return natural is
        variable v_num   : natural  := num;
        variable v_clog2 : natural  := 0;
    begin
        while (v_num > 0) loop
            v_clog2 := v_clog2 + 1;
            v_num   := v_num/2;
        end loop;
        return v_clog2;
    end function f_clog2;

    --function f_char_to_slv(c: character) return std_logic_vector is
    --begin
    --    return std_logic_vector(to_unsigned(character'pos(c), 8));
    --end function f_char_to_slv;

    --function f_str_to_msg(s: string) return t_data_bytes is
    --    variable v_msg : t_data_bytes(0 to s'length - 1);
    --begin
    --    for i in s'range loop
    --        v_msg(i - s'low)    := f_char_to_slv(s(i));
    --    end loop;
    --    return v_msg;
    --end function f_str_to_msg;

    constant c_CLK_CNT_WIDTH    : natural               := f_clog2(g_BIT_PERIOD);

    -- signals
    signal r_rx_state   : t_uart_state  := S_IDLE;
    signal r_tx_state   : t_uart_state  := S_IDLE;

    signal r_rx_bit     : std_logic                     := '1';
    signal r_rx_counter : unsigned(c_CLK_CNT_WIDTH-1 downto 0) := (others => '0');
    signal r_rx_bit_idx : unsigned(2 downto 0)          := (others => '0');
    signal r_rx_data    : std_logic_vector(7 downto 0)  := (others => '0');
    signal r_rx_valid   : std_logic                     := '0';

    signal r_tx_bit     : std_logic                     := '0';
    signal r_tx_data    : std_logic_vector(7 downto 0)  := (others => '0');
    --signal r_tx_bytes   : t_data_bytes(0 to c_message'length - 1)          := f_str_to_msg(c_message);
    signal r_tx_counter : unsigned(c_CLK_CNT_WIDTH-1 downto 0) := (others => '0');
    signal r_tx_bit_idx : unsigned(2 downto 0)          := (others => '0');
    signal r_tx_ready   : std_logic                     := '1';
    --signal r_tx_byte_idx: unsigned(8 downto 0)          := (others => '0');
    --signal r_butn1      : std_logic                     := '1';     --  active low

begin

    p_main: process(i_clk)
    begin

        if rising_edge(i_clk) then
            if (i_rstn = '0') then
                r_rx_state      <= S_IDLE;
                r_rx_bit        <= '1';
                r_rx_counter    <= (others => '0');
                r_rx_bit_idx    <= (others => '0');
                r_rx_data       <= (others => '1');
                --r_rx_dval       <= '0';
                r_tx_state      <= S_IDLE;
                r_tx_bit        <= '1';
                r_tx_counter    <= (others => '0');
                r_tx_bit_idx    <= (others => '0');
                r_tx_ready      <= '1';


            else
                r_rx_bit    <= i_uart_rx;
    
                UART_RX: case r_rx_state is
                    when S_IDLE =>
                        r_rx_counter    <= (others => '0');
                        r_rx_bit_idx    <= (others => '0');
                        r_rx_valid      <= '0';
                        if (r_rx_bit = '0') then
                            r_rx_state  <= S_START_BIT;
                        end if;
        
                    when S_START_BIT =>
                        if (r_rx_counter = c_half_bit_period - 1) then
                            if (r_rx_bit = '0') then
                                r_rx_state  <= S_DATA_BIT;
                                r_rx_counter<= (others => '0');
                            else
                                r_rx_state  <= S_IDLE;
                            end if;
                        else
                            r_rx_counter    <= r_rx_counter + 1;
                        end if;

                    when S_DATA_BIT =>
                        if (r_rx_counter = g_bit_period - 1) then
                            r_rx_data       <= r_rx_bit & r_rx_data(7 downto 1);
                            if (r_rx_bit_idx = to_unsigned(7, 3)) then
                                r_rx_state      <= S_STOP_BIT;
                                r_rx_bit_idx    <= (others => '0');
                            else
                                r_rx_bit_idx    <= r_rx_bit_idx + 1;
                            end if;
                            r_rx_counter    <= (others => '0');
                        else
                            r_rx_counter    <= r_rx_counter + 1;
                        end if;

                    when S_STOP_BIT =>
                        if (r_rx_counter = g_bit_period - 1) then
                            if (r_rx_bit = '1') then
                                r_rx_valid  <= '1';
                            end if;
                            r_rx_state  <= S_IDLE;
                        else
                            r_rx_counter    <= r_rx_counter + 1;
                        end if;

                    when others =>
                        r_rx_state  <= S_IDLE;
        
                end case UART_RX;

                -- TODO: replace tx state machine with a simple shift register and a counter???
                UART_TX: case r_tx_state is
                    when S_IDLE =>
                        r_tx_bit        <= '1';
                        r_tx_counter    <= (others => '0');
                        r_tx_bit_idx    <= (others => '0');
                        if (i_tx_dval = '1') then
                            r_tx_state      <= S_START_BIT;
                            r_tx_data       <= i_tx_data;
                            r_tx_ready      <= '0';
                        else
                            r_tx_ready      <= '1';
                        end if;

                    when S_START_BIT =>
                        r_tx_bit        <= '0';
                        if (r_tx_counter = g_bit_period - 1) then
                            r_tx_counter    <= (others => '0');
                            r_tx_state      <= S_DATA_BIT;
                        else
                            r_tx_counter    <= r_tx_counter + 1;
                        end if;

                    when S_DATA_BIT =>
                        r_tx_bit    <= r_tx_data(to_integer(r_tx_bit_idx));
                        if (r_tx_counter = g_bit_period - 1) then
                            r_tx_counter        <= (others => '0');
                            if (r_tx_bit_idx = 7) then
                                r_tx_bit_idx    <= (others=> '0');
                                r_tx_state      <= S_STOP_BIT;
                            else
                                r_tx_bit_idx    <= r_tx_bit_idx + 1;
                            end if;
                        else
                            r_tx_counter    <= r_tx_counter + 1;
                        end if;

                    when S_STOP_BIT =>
                        r_tx_bit    <= '1';
                        if (r_tx_counter = g_bit_period - 1) then
                            r_tx_counter    <= (others => '0');
                            r_tx_state      <= S_IDLE;
                            r_tx_ready      <= '1';
                        else
                            r_tx_counter    <= r_tx_counter + 1;
                        end if;

                    when others =>
                        r_tx_state  <= S_IDLE;
                
                end case UART_TX;

            end if;

        end if;


    end process p_main;

    o_uart_tx   <= r_tx_bit;
    o_rx_data   <= r_rx_data;
    o_rx_dval   <= r_rx_valid;
    o_tx_ready  <= r_tx_ready;


end architecture;
