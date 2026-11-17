library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

entity tb_top is
end tb_top;

architecture sim of tb_top is

    -- constants
    constant c_clk_freq      : natural := 27e6;
    constant c_clk_period    : time    := 1 sec / c_clk_freq;
    constant c_BIT_PERIOD    : natural := 234;                    -- clks per UART bit (115200)
    --constant c_bit_time      : time    := c_BIT_PERIOD * c_clk_period;
    constant c_bit_time      : time    := 8.680556 us;
    constant c_stim_file     : string  := "tb/sim_stim/short_150/in_short_150.csv";
    constant c_log_file      : string  := "tb/sim_logs/top_short_150.csv";

    type t_byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

    signal r_clk             : std_logic := '0';
    signal r_rstn            : std_logic := '0';
    signal r_uart_tx         : std_logic := '1';
    signal w_uart_rx         : std_logic;

    signal rx_cnt            : natural  := 0;
    signal tx_cnt            : natural  := 0;

    signal sim_done          : boolean  := false;

    component top is 
        generic (
            g_BIT_PERIOD    : natural                       := 234;     -- bit period in clk cycles: 27MHz clk, 115200 baud rate
            g_INTL_CONFIG   : std_logic_vector(2 downto 0)  := "000"    -- TODO: make it configurable in run
        );
        port (
            i_clk   : in std_logic;
            i_rstn  : in std_logic;
    
            i_uart_rx   : in  std_logic;
            o_uart_tx   : out std_logic   := '1';
    
            err_stat    : out std_logic_vector(5 downto 0)
        );
    end component;

    -- send one 8N1 byte on the UART rx pin
    procedure uart_send_byte(
        constant data    : in  std_logic_vector(7 downto 0);
        signal   uart_tx : out std_logic
    ) is
    begin
        uart_tx <= '0';                         -- start
        wait for c_bit_time;
        for i in 0 to 7 loop
            uart_tx <= data(i);                 -- LSB first
            wait for c_bit_time;
        end loop;
        uart_tx <= '1';                         -- stop
        wait for c_bit_time;
    end procedure;

    -- Counts data rows (skips the header and any line not starting with '0' or '1')
    impure function count_data_bits(file_name : string) return natural is
        file     f      : text;
        variable l      : line;
        variable ch     : character;
        variable status : file_open_status;
        variable cnt    : natural := 0;
    begin
        file_open(status, f, file_name, read_mode);
        assert status = open_ok
            report "Cannot open file: " & file_name severity failure;
    
        if not endfile(f) then
            readline(f, l);                 -- skip header "data,sop,eop"
        end if;
    
        while not endfile(f) loop
            readline(f, l);
            if l'length > 0 then
                read(l, ch);
                if ch = '0' or ch = '1' then
                    cnt := cnt + 1;
                end if;
            end if;
        end loop;
    
        file_close(f);
        return cnt;
    end function;
    
    constant N_BITS  : natural := count_data_bits(c_stim_file);
    constant N_BYTES : natural := (N_BITS + 7) / 8;   -- last partial byte zero-padded



    -- Reads the first column and packs every 8 bits into a byte (first bit = LSB)
    impure function read_bytes_from_file(file_name : string) return t_byte_array is
    
        variable result  : t_byte_array(0 to N_BYTES - 1) := (others => (others => '0'));
        file     f       : text;
        variable l       : line;
        variable ch      : character;
        variable status  : file_open_status;
        variable bit_idx : natural := 0;
    begin
        file_open(status, f, file_name, read_mode);
        assert status = open_ok
            report "Cannot open file: " & file_name severity failure;
    
        if not endfile(f) then
            readline(f, l);                 -- skip header
        end if;
    
        while not endfile(f) loop
            readline(f, l);
            if l'length > 0 then
                read(l, ch);                -- first column only
                if ch = '0' or ch = '1' then
                    if ch = '1' then
                        result(bit_idx / 8)(bit_idx mod 8) := '1';
                    end if;
                    bit_idx := bit_idx + 1;
                end if;
            end if;
        end loop;
    
        file_close(f);
        return result;
    end function;
    
    constant c_TX_BYTES : t_byte_array := read_bytes_from_file(c_stim_file);
    signal RX_BYTES : t_byte_array(0 to N_BYTES-1); 

begin

    -- clock / reset
    r_clk  <= not r_clk after c_clk_period/2 when not sim_done else '0';
    r_rstn <= '1' after 20 * c_clk_period;

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    top_inst: top
        generic map (g_BIT_PERIOD => c_BIT_PERIOD)
        port map (
            i_clk      => r_clk,
            i_rstn     => r_rstn,
            i_uart_rx  => r_uart_tx,
            o_uart_tx  => w_uart_rx,
            err_stat   => open
        );

    ---------------------------------------------------------------------------
    -- TX path: UART -> Avalon-ST
    ---------------------------------------------------------------------------

    -- stimulus: bytes into the UART rx pin (asynchronous to clk)
    p_tx_uart_stim: process
    begin
        wait until r_rstn = '1';
        wait for 3.3 * c_clk_period;            -- odd phase offset vs. the DUT clock
        for b in 0 to N_BYTES-1 loop
            uart_send_byte(c_TX_BYTES(b), r_uart_tx);
            tx_cnt  <= tx_cnt + 1;
            if b mod 3 = 2 then
                wait for 2.7 * c_bit_time;      -- idle gap now and then
            end if;
        end loop;
        wait for 1 ms;
        wait;
    end process;


    ---------------------------------------------------------------------------
    -- RX path: Avalon-ST -> UART
    ---------------------------------------------------------------------------

    -- monitor: sample the UART tx pin mid-bit and check each frame
    p_rx_uart_mon: process
        variable v_sh  : std_logic_vector(7 downto 0);
        variable v_err : natural := 0;
        file f          : text open write_mode is c_log_file;
        variable v_line : line;
        function std_logic_to_char(bit :std_logic)
            return character is
        begin
            if bit = '1' then
                return '1';
            elsif bit = '0' then
                return '0';
            elsif bit = 'U' then
                return 'U';
            elsif bit = 'X' then
                return 'X';
            else
                return '-';
            end if;
        end function std_logic_to_char;

    begin
        write(v_line, string'("data"));
        writeline(f, v_line);
        wait until r_rstn = '1';
        loop
            wait until w_uart_rx = '0';                 -- start bit edge
            wait for c_bit_time / 2;                    -- middle of start bit
            if w_uart_rx /= '0' then
                report "RX: glitch, start bit not stable at byte"
                    severity error;
            end if;
            for i in 0 to 7 loop
                wait for c_bit_time;
                v_sh(i) := w_uart_rx;
            end loop;
            wait for c_bit_time;                        -- middle of stop bit
            if w_uart_rx /= '1' then
                report "RX: bad stop bit at byte " severity error;
            end if;
            rx_cnt  <= rx_cnt + 1;
            RX_BYTES(rx_cnt) <= v_sh;
            for b in 0 to 7 loop
                write(v_line, std_logic_to_char(v_sh(b)));
                writeline(f, v_line);
            end loop;

        end loop;
        wait;
    end process;

--    ---------------------------------------------------------------------------
--    -- Control: wait for both directions, then report
--    ---------------------------------------------------------------------------
--    p_ctrl: process
--        file f  : text open write_mode is c_log_file;
--        variable l  : line ;
--        function std_logic_to_char(bit :std_logic)
--            return character is
--        begin
--            if bit = '1' then
--                return '1';
--            elsif bit = '0' then
--                return '0';
--            elsif bit = 'U' then
--                return 'U';
--            elsif bit = 'X' then
--                return 'X';
--            else
--                return '-';
--            end if;
--        end function std_logic_to_char;
--        variable last_time : time       := now;
--        variable last_val  : std_logic  := '1';
--        variable now_time : time       := now;
--    begin
--        --wait until (N_BYTES and tx_cnt = N_BYTES) for 5 ms;
--        loop 
--            if w_uart_rx /= last_val then
--                last_val    := w_uart_rx;
--                last_time   := now;
--            else
--                now_time    := now;
--                if (now_time - last_time) > 5 ms then
--                    break;
--                end if;
--            end if;
--
--        end loop;
--        wait for 5 * c_bit_time;                        -- catch spurious extra output
--
--        write(l, string'("data"));
--        writeline(f, l);
--
--        for byte in 0 to N_BYTES-1 loop
--            for b in 0 to 7 loop
--                write(l, std_logic_to_char(RX_BYTES(byte)(b)));
--                writeline(f, l);
--            end loop;
--        end loop;
--        
--        wait for 5 * c_bit_time;
--
--        sim_done <= true;
--        wait;
--    end process;

end architecture;
