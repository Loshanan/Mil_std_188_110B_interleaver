-- This tb test an overall functionality of the uart_avlnst_bridge module

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_avlnst_bridge is
end tb_uart_avlnst_bridge;

architecture sim of tb_uart_avlnst_bridge is

    -- constants
    constant c_clk_hz       : natural := 100e6;
    constant c_clk_period   : time    := 1 sec / c_clk_hz;

    signal r_clk            : std_logic := '0';
    signal r_rstn           : std_logic := '0';

    constant c_BIT_PERIOD   : natural   := 234; -- 115200
    constant c_message      : std_logic_vector(9 downto 0) := '1' & "00110011" & '0';       -- stop bit , data bit, start bit

    -- DUT IO

    -- component declarations
    component uart_avlnst_bridge is
        generic (
            g_BIT_PERIOD : natural := 234       -- bit period in clk cycles: 27MHz clk, 115200 baud rate
        );
        port (
            i_clk       : in  std_logic;
            i_rstn      : in  std_logic;        -- asynchronous reset, active low
            i_soft_rst  : in  std_logic;        -- synchronous reset, active high
    
            i_uart_rx   : in  std_logic;
            o_uart_tx   : out std_logic   := '1';
    
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

    -- component IO
    signal r_uart_rx    : std_logic := '1';
    signal r_m_ready    : std_logic := '1';
    signal w_m_valid    : std_logic;
    signal w_m_data     : std_logic;
    signal w_m_sop      : std_logic;
    signal w_m_eop      : std_logic;

    signal w_uart_tx    : std_logic;
    signal w_s_ready    : std_logic;
    signal r_s_data     : std_logic     := '0';
    signal r_s_valid    : std_logic     := '0';
    signal r_s_sop      : std_logic     := '0';
    signal r_s_eop      : std_logic     := '0';

    -- temp signal
    signal sim_done     : boolean   := false;

    procedure proc_send_uart(
        constant message  : in std_logic_vector(9 downto 0);
        signal uart_rx      : out std_logic
    ) is
    begin
        wait until rising_edge(r_clk);
        for i in 0 to 9 loop
            wait for 0.2 * c_clk_period;
            uart_rx   <= message(i);
            for j in 0 to c_bit_period-2 loop
                wait for c_clk_period;
            end loop;
            wait until rising_edge(r_clk);
        end loop;

        uart_rx   <= '1';
        
    end procedure proc_send_uart;

begin

    r_clk   <= not r_clk after c_clk_period/2 when not sim_done else '0';
    r_rstn  <= '1' after 20*c_clk_period;

    p_uart_rx: process
    begin
        wait until r_rstn = '1';
        wait for 5 * c_clk_period;

        for i in 0 to 100 loop
            proc_send_uart(c_message, r_uart_rx);
        end loop;

        wait for 20 * c_clk_period;
        sim_done    <= true;
        wait;

    end process p_uart_rx;

    p_uart_tx: process
        variable v_data_bit     : std_logic := '0';
    begin
        wait until r_rstn = '1';
        wait for 5 * c_clk_period;
        wait until rising_edge(r_clk);

        wait for 0.2 * c_clk_period;
        for i in 0 to 24 loop
            r_s_data    <= v_data_bit;
            r_s_valid   <= '1';
            wait until rising_edge(r_clk);
            while (w_s_ready = '0') loop
                wait until rising_edge(r_clk);
            end loop;

            wait for 0.2 * c_clk_period;
            r_s_valid   <= '0';
            v_data_bit  := not v_data_bit;

        end loop;
        
        wait;
    end process p_uart_tx;

    uart_avlnst_bridge_inst: uart_avlnst_bridge
        generic map(
            g_BIT_PERIOD => c_BIT_PERIOD
        )
        port map(
            i_clk       => r_clk,
            i_rstn      => r_rstn,
            i_soft_rst  => '0',
    
            i_uart_rx   => r_uart_rx,
            o_uart_tx   => w_uart_tx,
    
            m_ready     => r_m_ready,
            m_valid     => w_m_valid,
            m_data      => w_m_data,
            m_sop       => w_m_sop,
            m_eop       => w_m_eop,
    
            s_ready     => w_s_ready,
            s_valid     => r_s_valid,
            s_data      => r_s_data,
            s_sop       => r_s_sop,
            s_eop       => r_s_eop
    
        );
end architecture;
