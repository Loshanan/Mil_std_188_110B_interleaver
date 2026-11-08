-- Description  : Synchrounous FIFO with full, almost full, empty, almost empty flags
--                fifo depth is always power of 2
--                FWFT enabled
-- Author       : Mahalingam Loshanan
-- Started      : 2026-10-28
-- Last edited  : 2026-10-29

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_sync is 
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
end fifo_sync;

architecture arc_fifo_sync of fifo_sync is 

    -- constants
    constant c_DEPTH    : natural   := 2**g_ADDR_WIDTH;

    -- types
    type t_mem_array is array(0 to c_DEPTH-1) of std_logic_vector(g_WIDTH-1 downto 0);

    -- memory
    signal r_mem    : t_mem_array;

    -- IO signals
    --signal r_read_data  : std_logic_vector(g_WIDTH-1 downto 0)  := (others => '0');
    signal r_full       : std_logic             := '0';
    signal r_afull      : std_logic             := '0';
    signal r_empty      : std_logic             := '0';
    signal r_aempty     : std_logic             := '0';

    signal w_read_data  : std_logic_vector(g_WIDTH-1 downto 0)  := (others => '0');

    signal r_write_ptr  : unsigned(g_ADDR_WIDTH downto 0)       := (others => '0');
    signal r_read_ptr   : unsigned(g_ADDR_WIDTH downto 0)       := (others => '0');

    signal w_full_next      : std_logic;
    signal w_afull_next     : std_logic;
    signal w_empty_next     : std_logic;
    signal w_aempty_next    : std_logic;
    signal w_write_ptr_next : unsigned(g_ADDR_WIDTH downto 0)   := (others => '0');
    signal w_read_ptr_next  : unsigned(g_ADDR_WIDTH downto 0)   := (others => '0');

begin

    p_synchrounous: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rstn = '0' then
                r_write_ptr     <= (others => '0');
                r_read_ptr      <= (others => '0');
                r_full          <= '0';
                r_afull         <= '0';
                r_empty         <= '1';
                r_aempty        <= '1';
            else

                if (i_write_en = '1' and r_full = '0') then
                    r_mem(to_integer(r_write_ptr(g_ADDR_WIDTH-1 downto 0)))  <= i_write_data;
                    r_write_ptr     <= r_write_ptr + 1;
                end if;

                if (i_read_en = '1' and r_empty = '0') then
                    r_read_ptr      <= r_read_ptr + 1;
                end if;

                r_full      <= w_full_next;
                r_empty     <= w_empty_next;
                r_afull     <= w_afull_next;
                r_aempty    <= w_aempty_next;

            end if;
        end if;
    end process p_synchrounous;

    -- flags next state
    w_write_ptr_next    <= r_write_ptr + 1 when (i_write_en = '1' and r_full = '0') 
                            else r_write_ptr;

    w_read_ptr_next     <= r_read_ptr + 1 when (i_read_en = '1' and r_empty = '0')
                            else r_read_ptr;
        
    w_full_next         <= '1' when (w_write_ptr_next(g_ADDR_WIDTH) /= w_read_ptr_next(g_ADDR_WIDTH) 
                                        and w_write_ptr_next(g_ADDR_WIDTH-1 downto 0) = w_read_ptr_next(g_ADDR_WIDTH-1 downto 0))
                            else '0';

    w_empty_next        <= '1' when (w_write_ptr_next(g_ADDR_WIDTH downto 0) = w_read_ptr_next(g_ADDR_WIDTH downto 0))
                            else '0';

    w_aempty_next       <= '1' when (w_write_ptr_next - w_read_ptr_next < g_AE_LEVEL)
                            else '0';

    w_afull_next        <= '1' when (w_write_ptr_next - w_read_ptr_next > g_AF_LEVEL)
                            else '0';
    -- output assignments
    o_read_data     <= r_mem(to_integer(r_read_ptr(g_ADDR_WIDTH-1 downto 0)));
    o_full          <= r_full;
    o_empty         <= r_empty;
    o_afull         <= r_afull;
    o_aempty        <= r_aempty;

end architecture;
