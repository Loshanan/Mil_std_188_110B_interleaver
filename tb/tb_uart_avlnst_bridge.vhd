-- Self-checking testbench for uart_avlnst_bridge (VHDL-2008)
-- Written by Claude
--
--   TX path : UART (i_uart_rx pin) -> Avalon-ST source (m_*)   1 bit per beat, LSB first
--   RX path : Avalon-ST sink (s_*)  -> UART (o_uart_tx pin)    1 bit per beat, LSB first
--
-- sop/eop are not used by the bridge: s_sop/s_eop are tied low by the testbench and
-- m_sop/m_eop are ignored (not checked).
--
-- Backpressure checks:
--   TX path : m_ready is toggled pseudo-randomly. While m_valid=1 and m_ready=0 the
--             DUT must keep m_valid and m_data stable (Avalon-ST rule), and
--             no bit may be lost or duplicated.
--   RX path : the driver holds s_valid/s_data until s_ready=1. Data must
--             arrive intact on the UART pin; the number of cycles the DUT stalled
--             the source (s_valid=1, s_ready=0) is reported.
--
-- ASSUMPTIONS (change if your DUT differs):
--   * 8N1 UART, LSB first
--   * each UART byte <-> 8 Avalon-ST beats (1 bit each)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_avlnst_bridge is
end tb_uart_avlnst_bridge;

architecture sim of tb_uart_avlnst_bridge is

    -- constants
    constant c_clk_period    : time    := 10 ns;                  -- 100 MHz
    constant c_BIT_PERIOD    : natural := 234;                    -- clks per UART bit (115200)
    constant c_bit_time      : time    := c_BIT_PERIOD * c_clk_period;
    constant c_BACKPRESSURE  : boolean := true;                   -- toggle m_ready

    type t_byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

    constant c_N        : natural := 10;
    -- UART -> Avalon-ST (TX path)
    constant c_TX_BYTES : t_byte_array(0 to c_N-1) :=
        (x"00", x"FF", x"55", x"AA", x"01", x"80", x"A5", x"5A", x"3C", x"C3");
    -- Avalon-ST -> UART (RX path)
    constant c_RX_BYTES : t_byte_array(0 to c_N-1) :=
        (x"FF", x"00", x"AA", x"55", x"80", x"01", x"5A", x"A5", x"C3", x"3C");

    -- DUT declaration
    component uart_avlnst_bridge is
        generic (
            g_BIT_PERIOD : natural := 234
        );
        port (
            i_clk       : in  std_logic;
            i_rstn      : in  std_logic;
            i_soft_rst  : in  std_logic;

            i_uart_rx   : in  std_logic;
            o_uart_tx   : out std_logic := '1';

            m_ready     : in  std_logic;
            m_valid     : out std_logic;
            m_data      : out std_logic;
            m_sop       : out std_logic;
            m_eop       : out std_logic;

            s_ready     : out std_logic;
            s_valid     : in  std_logic;
            s_data      : in  std_logic;
            s_sop       : in  std_logic;
            s_eop       : in  std_logic
        );
    end component;

    -- signals
    signal r_clk        : std_logic := '0';
    signal r_rstn       : std_logic := '0';
    signal sim_done     : boolean   := false;

    signal r_uart_rx    : std_logic := '1';
    signal w_uart_tx    : std_logic;

    signal r_m_ready    : std_logic := '1';
    signal w_m_valid    : std_logic;
    signal w_m_data     : std_logic;
    signal w_m_sop      : std_logic;
    signal w_m_eop      : std_logic;

    signal w_s_ready    : std_logic;
    signal r_s_valid    : std_logic := '0';
    signal r_s_data     : std_logic := '0';
    signal r_s_sop      : std_logic := '0';
    signal r_s_eop      : std_logic := '0';

    -- scoreboard
    signal tx_cnt, tx_err : natural := 0;    -- UART -> Avalon-ST
    signal rx_cnt, rx_err : natural := 0;    -- Avalon-ST -> UART
    signal m_stall_cnt    : natural := 0;    -- cycles with m_valid=1, m_ready=0
    signal s_stall_cnt    : natural := 0;    -- cycles with s_valid=1, s_ready=0

    -- send one 8N1 byte on the UART rx pin
    procedure uart_send_byte(
        constant data    : in  std_logic_vector(7 downto 0);
        signal   uart_rx : out std_logic
    ) is
    begin
        uart_rx <= '0';                         -- start
        wait for c_bit_time;
        for i in 0 to 7 loop
            uart_rx <= data(i);                 -- LSB first
            wait for c_bit_time;
        end loop;
        uart_rx <= '1';                         -- stop
        wait for c_bit_time;
    end procedure;

begin

    -- clock / reset
    r_clk  <= not r_clk after c_clk_period/2 when not sim_done else '0';
    r_rstn <= '1' after 20 * c_clk_period;

    ---------------------------------------------------------------------------
    -- DUT
    ---------------------------------------------------------------------------
    dut: uart_avlnst_bridge
        generic map (g_BIT_PERIOD => c_BIT_PERIOD)
        port map (
            i_clk      => r_clk,
            i_rstn     => r_rstn,
            i_soft_rst => '0',
            i_uart_rx  => r_uart_rx,
            o_uart_tx  => w_uart_tx,
            m_ready    => r_m_ready,
            m_valid    => w_m_valid,
            m_data     => w_m_data,
            m_sop      => w_m_sop,
            m_eop      => w_m_eop,
            s_ready    => w_s_ready,
            s_valid    => r_s_valid,
            s_data     => r_s_data,
            s_sop      => r_s_sop,
            s_eop      => r_s_eop
        );

    ---------------------------------------------------------------------------
    -- TX path: UART -> Avalon-ST
    ---------------------------------------------------------------------------

    -- stimulus: bytes into the UART rx pin (asynchronous to clk)
    p_tx_uart_stim: process
    begin
        wait until r_rstn = '1';
        wait for 3.3 * c_clk_period;            -- odd phase offset vs. the DUT clock
        for b in 0 to c_N-1 loop
            uart_send_byte(c_TX_BYTES(b), r_uart_rx);
            if b mod 3 = 2 then
                wait for 2.7 * c_bit_time;      -- idle gap now and then
            end if;
        end loop;
        wait;
    end process;

    -- backpressure generator on m_ready (pseudo-random LFSR bursts)
    p_m_ready: process
        variable v_lfsr : unsigned(15 downto 0) := x"ACE1";
        variable v_low  : natural;
        variable v_high : natural;
    begin
        r_m_ready <= '1';
        wait until r_rstn = '1';
        if not c_BACKPRESSURE then
            wait;
        end if;
        loop
            v_lfsr := v_lfsr(14 downto 0) & (v_lfsr(15) xor v_lfsr(13) xor v_lfsr(12) xor v_lfsr(10));
            v_low  := to_integer(v_lfsr(3 downto 0));          -- 0..15 (+1) cycles low
            v_high := to_integer(v_lfsr(6 downto 4)) + 1;      -- 1..8 cycles high
            r_m_ready <= '0';
            for k in 0 to v_low loop
                wait until rising_edge(r_clk);
            end loop;
            r_m_ready <= '1';
            for k in 1 to v_high loop
                wait until rising_edge(r_clk);
            end loop;
        end loop;
    end process;

    -- monitor: collect beats, compare bytes, check stall stability
    p_tx_avl_mon: process (r_clk)
        variable v_bitcnt     : natural := 0;
        variable v_idx        : natural := 0;
        variable v_sh         : std_logic_vector(7 downto 0) := (others => '0');
        variable v_err        : natural := 0;
        variable v_stalls     : natural := 0;
        variable v_prev_stall : boolean := false;
        variable v_prev_data  : std_logic := '0';
    begin
        if rising_edge(r_clk) then
            if r_rstn = '1' then

                -- Avalon-ST rule: after a stalled beat, valid and payload must hold
                if v_prev_stall then
                    if w_m_valid /= '1' then
                        report "TX: m_valid dropped during backpressure" severity error;
                        v_err := v_err + 1;
                    elsif w_m_data /= v_prev_data then
                        report "TX: m_data changed during backpressure" severity error;
                        v_err := v_err + 1;
                    end if;
                end if;

                v_prev_stall := (w_m_valid = '1' and r_m_ready = '0');
                v_prev_data  := w_m_data;
                if v_prev_stall then
                    v_stalls := v_stalls + 1;
                end if;

                -- accepted beat
                if w_m_valid = '1' and r_m_ready = '1' then
                    if v_idx >= c_N then
                        report "TX: unexpected extra beat from DUT" severity error;
                        v_err := v_err + 1;
                    else
                        v_sh(v_bitcnt) := w_m_data;             -- LSB first

                        if v_bitcnt = 7 then
                            if v_sh /= c_TX_BYTES(v_idx) then
                                report "TX: byte " & integer'image(v_idx) & " mismatch, got 0x" &
                                       to_hstring(v_sh) & " expected 0x" &
                                       to_hstring(c_TX_BYTES(v_idx)) severity error;
                                v_err := v_err + 1;
                            end if;
                            v_idx    := v_idx + 1;
                            v_bitcnt := 0;
                        else
                            v_bitcnt := v_bitcnt + 1;
                        end if;
                    end if;
                end if;

                tx_cnt      <= v_idx;
                tx_err      <= v_err;
                m_stall_cnt <= v_stalls;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- RX path: Avalon-ST -> UART
    ---------------------------------------------------------------------------

    -- stimulus: 1-bit beats with a proper valid/ready handshake; inputs are held
    -- unchanged until the DUT accepts the beat (s_ready=1 at a clock edge)
    p_rx_avl_stim: process
    begin
        r_s_valid <= '0';
        wait until r_rstn = '1';
        wait for 5 * c_clk_period;
        wait until rising_edge(r_clk);

        for b in 0 to c_N-1 loop
            for i in 0 to 7 loop
                r_s_data  <= c_RX_BYTES(b)(i);                  -- LSB first
                r_s_valid <= '1';

                loop
                    wait until rising_edge(r_clk);
                    exit when w_s_ready = '1';
                end loop;
            end loop;

            r_s_valid <= '0';
            -- small gap between bytes (varies per byte)
            for k in 0 to (b * 7) mod 5 loop
                wait until rising_edge(r_clk);
            end loop;
        end loop;
        wait;
    end process;

    -- count how often the DUT backpressures the source
    p_s_stall_mon: process (r_clk)
        variable v_stalls : natural := 0;
    begin
        if rising_edge(r_clk) then
            if r_rstn = '1' and r_s_valid = '1' and w_s_ready = '0' then
                v_stalls := v_stalls + 1;
            end if;
            s_stall_cnt <= v_stalls;
        end if;
    end process;

    -- monitor: sample the UART tx pin mid-bit and check each frame
    p_rx_uart_mon: process
        variable v_sh  : std_logic_vector(7 downto 0);
        variable v_err : natural := 0;
    begin
        wait until r_rstn = '1';
        for b in 0 to c_N-1 loop
            wait until w_uart_tx = '0';                 -- start bit edge
            wait for c_bit_time / 2;                    -- middle of start bit
            if w_uart_tx /= '0' then
                report "RX: glitch, start bit not stable at byte " & integer'image(b)
                    severity error;
                v_err := v_err + 1;
            end if;
            for i in 0 to 7 loop
                wait for c_bit_time;
                v_sh(i) := w_uart_tx;
            end loop;
            wait for c_bit_time;                        -- middle of stop bit
            if w_uart_tx /= '1' then
                report "RX: bad stop bit at byte " & integer'image(b) severity error;
                v_err := v_err + 1;
            end if;
            if v_sh /= c_RX_BYTES(b) then
                report "RX: byte " & integer'image(b) & " mismatch, got 0x" &
                       to_hstring(v_sh) & " expected 0x" &
                       to_hstring(c_RX_BYTES(b)) severity error;
                v_err := v_err + 1;
            end if;
            rx_cnt <= b + 1;
            rx_err <= v_err;
        end loop;
        wait;
    end process;

    ---------------------------------------------------------------------------
    -- Control: wait for both directions, then report
    ---------------------------------------------------------------------------
    p_ctrl: process
    begin
        wait until (rx_cnt = c_N and tx_cnt = c_N) for 5 ms;
        wait for 5 * c_bit_time;                        -- catch spurious extra output

        if tx_cnt /= c_N then
            report "TX: timeout, only " & integer'image(tx_cnt) & " bytes received on Avalon-ST"
                severity error;
        end if;
        if rx_cnt /= c_N then
            report "RX: timeout, only " & integer'image(rx_cnt) & " bytes seen on UART tx pin"
                severity error;
        end if;

        report "m_ready backpressure cycles seen by DUT output: " & integer'image(m_stall_cnt)
            severity note;
        report "s_ready backpressure cycles seen by source:     " & integer'image(s_stall_cnt)
            severity note;
        if c_BACKPRESSURE and m_stall_cnt = 0 then
            report "TX: m_ready backpressure was never exercised (m_valid never high while m_ready low)"
                severity warning;
        end if;
        if s_stall_cnt = 0 then
            report "RX: DUT never deasserted s_ready, source backpressure not exercised"
                severity warning;
        end if;

        if rx_cnt = c_N and tx_cnt = c_N and rx_err = 0 and tx_err = 0 then
            report "TEST PASSED" severity note;
        else
            report "TEST FAILED: tx_err=" & integer'image(tx_err) &
                   " rx_err=" & integer'image(rx_err) severity error;
        end if;

        sim_done <= true;
        wait;
    end process;

end architecture;
