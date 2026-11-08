library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_avlnst_bridge is
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

architecture arc_uart_avlnst_bridge of uart_avlnst_bridge is

    -------------------------------------------------
    -- constant
    -------------------------------------------------
    -- uart baud rate
    constant c_BIT_PERIOD   : natural := g_BIT_PERIOD;
    -- fifo constants
    constant c_WIDTH        : natural := 8;
    constant c_ADDR_WIDTH   : natural := 5;
    constant c_AE_LEVEL     : natural := 8;
    constant c_AF_LEVEL     : natural := 24;
    -- total bye count
    constant c_BYTE_CNT     : natural := 90; -- 90 for 150bps short intl setting

    -------------------------------------------------
    -- mem type
    -------------------------------------------------

    -------------------------------------------------
    -- signal declaration 
    -------------------------------------------------
    signal w_uart_tx_ready  : std_logic;

    signal w_rx_fifo_data   : std_logic_vector(7 downto 0);
    signal w_rx_fifo_wren   : std_logic;
    signal w_rx_fifo_q      : std_logic_vector(7 downto 0);
    signal r_rx_fifo_q      : std_logic_vector(7 downto 0)  := (others => '0');
    signal w_rx_fifo_rden   : std_logic;
    signal w_rx_fifo_empty  : std_logic;
    signal r_rx_sr_val      : std_logic_vector(7 downto 0)  := (others => '0');
    signal r_rx_sr_sop      : std_logic_vector(7 downto 0)  := (others => '0');
    signal r_rx_sr_eop      : std_logic_vector(7 downto 0)  := (others => '0');
    signal r_rx_byte_cnt    : unsigned(10 downto 00)        := (others => '0');

    signal w_tx_fifo_afull  : std_logic;
    signal r_tx_sr_val      : std_logic_vector(7 downto 0)  := (others => '0');
    signal r_tx_sr_data     : std_logic_vector(7 downto 0)  := (others => '0');
    signal w_tx_fifo_empty  : std_logic;
    signal w_tx_fifo_q      : std_logic_vector(7 downto 0);
    signal w_tx_fifo_rden   : std_logic;

    -------------------------------------------------
    -- component declaration 
    -------------------------------------------------
    component uart_trx is 
        generic (
            g_bit_period : natural := 234       -- bit period in clk cycles: 27MHz clk, 115200 baud rate
        );
        port (
            i_clk     : in  std_logic;
            i_rstn    : in  std_logic;
            i_uart_rx : in  std_logic;
            o_uart_tx : out std_logic   := '1';
            o_rx_data : out std_logic_vector(7 downto 0);
            o_rx_dval : out std_logic;
            i_tx_data : in  std_logic_vector(7 downto 0);
            i_tx_dval : in  std_logic;
            o_tx_ready: out std_logic
        );
    end component;

    component fifo_sync is 
        generic (
            g_WIDTH         : natural   := 8;
            g_ADDR_WIDTH    : natural   := 5;
            g_AE_LEVEL      : natural   := 8;
            g_AF_LEVEL      : natural   := 24
        );
        port (
            i_clk   : in std_logic;
            i_rstn  : in std_logic;
    
            -- fifo write interface
            i_write_en      : in  std_logic;
            i_write_data    : in  std_logic_vector(g_WIDTH-1 downto 0);
            o_full          : out std_logic;
            o_afull         : out std_logic;
    
            -- fifo read interface
            i_read_en       : in  std_logic;
            o_read_data     : out std_logic_vector(g_WIDTH-1 downto 0);
            o_empty         : out std_logic;
            o_aempty        : out std_logic
    
        );
    end component;

begin

    p_main: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rstn = '0' then
                r_rx_fifo_q     <= (others => '0');
                r_rx_sr_val     <= (others => '0');
                r_rx_sr_sop     <= (others => '0');
                r_rx_sr_eop     <= (others => '0');
                r_rx_byte_cnt   <= (others => '0');
            else
                -- from uart to avalon stream
                if (w_rx_fifo_rden = '1') then
                    r_rx_fifo_q     <= w_rx_fifo_q;
                    r_rx_sr_val     <= (others => '1');
                    -- count bytes
                    if (r_rx_byte_cnt = c_BYTE_CNT-1) then 
                        r_rx_byte_cnt   <= (others => '0');
                    else
                        r_rx_byte_cnt   <= r_rx_byte_cnt + 1;
                    end if;
                    -- sop array
                    if (r_rx_byte_cnt = 0) then
                        r_rx_sr_sop     <= (0 => '1', others => '0');
                    else
                        r_rx_sr_sop     <= (others => '0');
                    end if;
                    -- eop array
                    if (r_rx_byte_cnt = to_unsigned(c_BYTE_CNT-1, 11)) then
                        r_rx_sr_eop     <= (7 => '1', others => '0');
                    else
                        r_rx_sr_eop     <= (others => '0');
                    end if;
                else
                    if (m_ready = '1') then
                        r_rx_fifo_q     <= '0' & r_rx_fifo_q(7 downto 1);
                        r_rx_sr_val     <= '0' & r_rx_sr_val(7 downto 1);
                        r_rx_sr_sop     <= '0' & r_rx_sr_sop(7 downto 1);
                        r_rx_sr_eop     <= '0' & r_rx_sr_eop(7 downto 1);
                    end if;
                end if;

                -- from avalon stream to uart
                if (r_tx_sr_val(7) = '1') then
                    r_tx_sr_val     <= (others => '0');
                else
                    if ((s_valid and (not r_tx_sr_val(7)) and (not w_tx_fifo_afull)) = '1') then
                        r_tx_sr_data    <= r_tx_sr_data(6 downto 0) & s_data;
                        r_tx_sr_val     <= r_tx_sr_val(6 downto 0) & '1';
                    end if;
                end if;

            end if;
        end if;
    end process p_main;

    -- fifo IO
    -- UART to avalon stream
    w_rx_fifo_rden  <= m_ready and (not w_rx_fifo_empty) and not r_rx_sr_val(0);
    -- avalon stream to UART
    w_tx_fifo_rden  <= (not w_tx_fifo_empty) and w_uart_tx_ready;

    -- output regs
    m_valid     <= r_rx_sr_val(0);
    m_data      <= r_rx_fifo_q(0);
    m_sop       <= r_rx_sr_sop(0);
    m_eop       <= r_rx_sr_eop(0); 
    s_ready     <= (not r_tx_sr_val(7)) and (not w_tx_fifo_afull);

    uart_trx_inst   : uart_trx
        generic map(
            g_bit_period    => c_BIT_PERIOD
        )
        port map(
            i_clk     => i_clk,
            i_rstn    => i_rstn,
            i_uart_rx => i_uart_rx,
            o_uart_tx => o_uart_tx,
            o_rx_data => w_rx_fifo_data,
            o_rx_dval => w_rx_fifo_wren,
            i_tx_data => w_tx_fifo_q,
            i_tx_dval => w_tx_fifo_rden,
            o_tx_ready=> w_uart_tx_ready
        );

    fifo_sync_rx_inst  : fifo_sync 
    generic map(
        g_WIDTH         => c_WIDTH,
        g_ADDR_WIDTH    => c_ADDR_WIDTH,
        g_AE_LEVEL      => c_AE_LEVEL,
        g_AF_LEVEL      => c_AF_LEVEL
    )
    port map(
        i_clk           => i_clk,
        i_rstn          => i_rstn,
        i_write_en      => w_rx_fifo_wren,
        i_write_data    => w_rx_fifo_data,
        o_full          => open,        -- TODO: make full as a top level error signal since there is no stall propagation
        o_afull         => open,
        i_read_en       => w_rx_fifo_rden,
        o_read_data     => w_rx_fifo_q,
        o_empty         => w_rx_fifo_empty,
        o_aempty        => open 
    );

    -- TODO: check sop and eop position
    fifo_sync_tx_inst  : fifo_sync 
    generic map(
        g_WIDTH         => c_WIDTH,
        g_ADDR_WIDTH    => c_ADDR_WIDTH,
        g_AE_LEVEL      => c_AE_LEVEL,
        g_AF_LEVEL      => c_AF_LEVEL
    )
    port map(
        i_clk           => i_clk,
        i_rstn          => i_rstn,
        i_write_en      => r_tx_sr_val(7),
        i_write_data    => r_tx_sr_data,
        o_full          => open,
        o_afull         => w_tx_fifo_afull,
        i_read_en       => w_tx_fifo_rden,
        o_read_data     => w_tx_fifo_q,
        o_empty         => w_tx_fifo_empty,
        o_aempty        => open 
    );

end architecture;
