-- Description  : Top module for board setup of interleaver module in Tang nano 9K fpga
-- Author       : Mahalingam Loshanan
-- Started      : 2026-11-01
-- Last edited  : 2026-11-01

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is 
    generic (
        g_BIT_PERIOD    : natural                       := 234;     -- bit period in clk cycles: 27MHz clk, 115200 baud rate
        g_INTL_CONFIG   : std_logic_vector(2 downto 0)  := "000"    -- TODO: make it configurable in run
    );
    port (
        i_clk   : in std_logic;
        i_rstn  : in std_logic;

        i_uart_rx   : in  std_logic;
        o_uart_tx   : out std_logic   := '1'

    );
end top;

architecture arc_top of top is 

    -- constants

    -- types

    -- memory

    -- IO signals

    -- conponents
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
    end uart_avlnst_bridge;

    component hf_mod_interleaver is
        port (
            i_clk       : in  std_logic;
            i_rstn      : in  std_logic;        -- asynchronous reset, active low
            i_soft_rst  : in  std_logic;        -- synchronous reset, active high
    
            s_ready     : out std_logic;
            s_valid     : in  std_logic;
            s_data      : in  std_logic;
            s_sop       : in  std_logic;
            s_eop       : in  std_logic;
    
            m_ready     : in  std_logic;
            m_valid     : out std_logic;
            m_data      : out std_logic;
            m_sop       : out std_logic;
            m_eop       : out std_logic;
    
            i_config    : std_logic_vector(2 downto 0)  -- [1:0] = bit rate(0: 150, 1: 300, 2: 600, 3: 1200)
                                                        -- [2]   = interleaver mode (0: short, 1: long)
        );
    end hf_mod_interleaver;

    -- component IO
    -- Input to the interleaver
    signal w_tx_ready   : std_logic;
    signal w_tx_valid   : std_logic;
    signal w_tx_data    : std_logic;
    signal w_tx_sop     : std_logic;
    signal w_tx_eop     : std_logic;

    -- Output from interleaver
    signal w_rx_ready   : std_logic;
    signal w_rx_valid   : std_logic;
    signal w_rx_data    : std_logic;
    signal w_rx_sop     : std_logic;
    signal w_rx_eop     : std_logic;

begin

    uart_avlnst_bridge_inst : uart_avlnst_bridge
    generic map(
        g_BIT_PERIOD    => g_BIT_PERIOD
    );
    port map(
        i_clk       => i_clk,
        i_rstn      => i_rstn,
        i_soft_rst  => '0',
        i_uart_rx   => i_uart_rx,
        o_uart_tx   => o_uart_tx,
        m_ready     => w_tx_ready,
        m_valid     => w_tx_valid,
        m_data      => w_tx_data,
        m_sop       => w_tx_sop,
        m_eop       => w_tx_eop,
        s_ready     => w_rx_ready,
        s_valid     => w_rx_valid,
        s_data      => w_rx_data,
        s_sop       => w_rx_sop,
        s_eop       => w_rx_eop
    );

    hf_mod_interleaver_inst : hf_mod_interleaver
    port map(
        i_clk       => i_clk,
        i_rstn      => i_rstn,
        i_soft_rst  => '0',
        s_ready     => w_rx_ready,
        s_valid     => w_rx_valid,
        s_data      => w_rx_data,
        s_sop       => w_rx_sop,
        s_eop       => w_rx_eop,
        m_ready     => w_tx_ready,
        m_valid     => w_tx_valid,
        m_data      => w_tx_data,
        m_sop       => w_tx_sop,
        m_eop       => w_tx_eop,
        i_config    => g_INTL_CONFIG
    );
end architecture;
