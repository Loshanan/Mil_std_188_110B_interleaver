library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hf_mod_interleaver is
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

architecture arc_interleaver of hf_mod_interleaver is

    -------------------------------------------------
    -- mem type
    -------------------------------------------------
    constant c_n_rows       : natural := 40;
    constant c_n_max_cols   : natural := 288;
    type t_ram is array(0 to (c_n_rows*c_n_max_cols)-1) of std_logic;
    signal r_mem_1  : t_ram;
    signal r_mem_2  : t_ram;

    -------------------------------------------------
    -- signal declaration - Config
    -------------------------------------------------
    signal r_cfg_bit_rate   : std_logic_vector(1 downto 0)  := (others => '0'); -- 0: 150, 1: 300, 2: 600, 3: 1200
    signal r_cfg_intl_mode  : std_logic                     := '0';             -- 0: short, 1: long
    signal r_cfg_col_count  : unsigned(8 downto 0)          := to_unsigned(18, 9);

    -------------------------------------------------
    -- signal declaration - WRITE pipeline
    -------------------------------------------------
    -- Stage 0 : input regs and others
    signal w_s_ready     : std_logic;
    signal r_s_valid     : std_logic  := '0';
    signal r_s_data      : std_logic  := '0';
    signal r_s_sop       : std_logic  := '0';
    signal r_s_eop       : std_logic  := '0';
    signal r_sr_wf_count : std_logic_vector(23 downto 0)  := (0 => '1', others => '0');   -- written frame counter    
    signal r_write_pnter_s0 : unsigned(1 downto 0)        := to_unsigned(0, 2);

    -- Stage 1 
    signal r_write_valid_s1 : std_logic             := '0';
    signal r_write_data_s1  : std_logic             := '0';
    signal r_write_row_s1   : unsigned(5 downto 0)  := to_unsigned(0, 6); -- counts from 0 to 39
    signal r_write_col_s1   : unsigned(8 downto 0)  := to_unsigned(0, 9); -- counts from 0 to 288 at maximum
    signal r_write_pnter_s1 : unsigned(1 downto 0)  := to_unsigned(0, 2);

    -- Stage 2
    signal r_write_valid_s2 : std_logic             := '0';
    signal r_write_data_s2  : std_logic             := '0';
    signal r_write_row_s2   : unsigned(5 downto 0)  := to_unsigned(0, 6);
    signal r_write_col_s2   : unsigned(13 downto 0) := to_unsigned(0, 14);
    signal r_write_pnter_s2 : unsigned(1 downto 0)  := to_unsigned(0, 2);

    -- Stage 3
    signal r_write_valid_s3 : std_logic             := '0';
    signal r_write_data_s3  : std_logic             := '0';
    signal r_write_addr_s3  : unsigned(13 downto 00):= to_unsigned(0, 14);   -- maximum matrix size 40 X 288 = 11520
    signal r_write_pnter_s3 : unsigned(1 downto 0)  := to_unsigned(0, 2);

    -- Stage 4
    signal r_write_pnter_s4 : unsigned(1 downto 0)  := to_unsigned(0, 2);

    -- other intermediate wires
    signal w_intl_empty     : std_logic;
    signal w_intl_half      : std_logic;
    signal w_intl_full      : std_logic;
    signal w_last_f_short   : std_logic;
    signal w_last_f_long    : std_logic;
    signal w_first_f_short  : std_logic;
    signal w_first_f_long   : std_logic;


    -------------------------------------------------
    -- signal declaration - READ pipeline
    -------------------------------------------------
    -- Stage 0
    signal r_read_valid_s0  : std_logic               := '0';
    signal r_read_sop_s0    : std_logic               := '0';
    signal r_read_eop_s0    : std_logic               := '0';
    signal r_read_row_s0    : unsigned(5 downto 0)    := to_unsigned(0, 6);
    signal r_read_col_s0    : unsigned(8 downto 0)    := to_unsigned(0, 9);
    signal r_read_col_last_row0: unsigned(8 downto 0) := to_unsigned(0, 9);
    -- signal r_sr_rf_count    : std_logic_vector(23 downto 00);   -- read frame counter
    signal r_read_pnter_s0  : unsigned(1 downto 0)    := to_unsigned(0, 2);
    signal r_sr_18_count    : std_logic_vector(17 downto 00)  := (others => '0');
    signal r_sr_16_count    : std_logic_vector(15 downto 00)  := (others => '0');

    -- Stage 1
    signal r_read_valid_s1  : std_logic             := '0';
    signal r_read_sop_s1    : std_logic             := '0';
    signal r_read_eop_s1    : std_logic             := '0';
    signal r_read_row_s1    : unsigned(5 downto 0)  := to_unsigned(0, 6);
    signal r_read_col_s1    : unsigned(13 downto 0) := to_unsigned(0, 14);    -- col X 40
    signal r_read_pnter_s1  : unsigned(1 downto 0)  := to_unsigned(0, 2);

    --- Stage 2
    signal r_read_valid_s2  : std_logic             := '0';
    signal r_read_sop_s2    : std_logic             := '0';
    signal r_read_eop_s2    : std_logic             := '0';
    signal r_read_addr_s2   : unsigned(13 downto 00):= to_unsigned(0, 14);
    signal r_read_pnter_s2  : unsigned(1 downto 0)  := to_unsigned(0, 2);
    
    -- Stage 3
    signal r_read_valid_s3  : std_logic             := '0';
    signal r_read_sop_s3    : std_logic             := '0';
    signal r_read_eop_s3    : std_logic             := '0';
    signal r_read_pnter_s3  : unsigned(1 downto 0)  := to_unsigned(0, 2);

    -- Stage 4
    signal r_m_read_data    : std_logic             := '0';
    signal r_m_read_valid   : std_logic             := '0';
    signal r_m_read_sop     : std_logic             := '0';
    signal r_m_read_eop     : std_logic             := '0';
    signal r_read_pnter_s4  : unsigned(1 downto 0)  := to_unsigned(0, 2);

    -- read mem signals
    signal r_raddr_mem1     : unsigned(13 downto 00)  := to_unsigned(0, 14);
    signal r_raddr_mem2     : unsigned(13 downto 00)  := to_unsigned(0, 14);
    signal w_rdata_mem1     : std_logic;
    signal w_rdata_mem2     : std_logic;

    signal w_last_18_col    : std_logic;
    signal w_last_36_col    : std_logic;
    signal w_last_144_col   : std_logic;
    signal w_last_288_col   : std_logic;
    signal w_last_intl_col  : std_logic;
    
begin

    ASYNC_PROC : process(i_clk, i_rstn)
    begin
        if i_rstn = '0' then
            r_cfg_bit_rate  <= (others => '0');
            r_cfg_intl_mode <= '0';
            r_cfg_col_count <= to_unsigned(18, 9);

            r_s_valid       <= '0';
            r_s_data        <= '0';
            r_s_sop         <= '0';
            r_s_eop         <= '0';
            r_sr_wf_count   <= (0 => '1', others => '0');
            r_write_pnter_s0   <= (others => '0');
            
            r_write_valid_s1    <= '0';
            r_write_data_s1     <= '0';
            r_write_row_s1      <= (others => '0');
            r_write_col_s1      <= (others => '0');
            r_write_pnter_s1    <= (others => '0');

            r_write_valid_s2    <= '0';
            r_write_data_s2     <= '0';
            r_write_row_s2      <= (others => '0');
            r_write_col_s2      <= (others => '0');
            r_write_pnter_s2    <= (others => '0');

            r_write_valid_s3    <= '0';
            r_write_data_s3     <= '0';
            r_write_addr_s3     <= (others => '0');
            r_write_pnter_s3    <= (others => '0');

            r_write_pnter_s4    <= (others => '0');

            r_read_valid_s0     <= '0';
            r_read_sop_s0       <= '0';
            r_read_eop_s0       <= '0';
            r_read_row_s0       <= (others => '0');
            r_read_col_s0       <= (others => '0');
            r_read_col_last_row0<= (others => '0');

            r_read_pnter_s0     <= (others => '0');
            r_sr_18_count       <= (0 => '1', others => '0');
            r_sr_16_count       <= (0 => '1', others => '0');

            r_read_valid_s1     <= '0';
            r_read_sop_s1       <= '0';
            r_read_eop_s1       <= '0';
            r_read_row_s1       <= (others => '0');
            r_read_col_s1       <= (others => '0');
            r_read_pnter_s1     <= (others => '0');

            r_read_valid_s2     <= '0';
            r_read_sop_s2       <= '0';
            r_read_eop_s2       <= '0';
            --r_read_addr_s2      <= (others => '0');
            r_read_pnter_s2     <= (others => '0');

            r_read_valid_s3     <= '0';
            r_read_sop_s3       <= '0';
            r_read_eop_s3       <= '0';
            r_read_pnter_s3     <= (others => '0');

            r_m_read_data       <= '0';
            r_m_read_valid      <= '0';
            r_m_read_data       <= '0';
            r_m_read_sop        <= '0';
            r_m_read_eop        <= '0';
            r_read_pnter_s4     <= (others => '0');

            --r_raddr_mem1        <= (others => '0');
            --r_raddr_mem2        <= (others => '0');

        elsif rising_edge(i_clk) then

            ---------------------------------------------------------------
            ------------------- WRITE LOGIC -------------------------------
            ---------------------------------------------------------------
            if (w_s_ready = '1' and s_valid = '1') then
                ---------------------------------------------------------------
                -- registering config with first sop while interleaver is empty
                ---------------------------------------------------------------
                if (w_intl_empty = '1' and s_sop = '1' and r_sr_wf_count(0) = '1') then
                    r_cfg_bit_rate  <= i_config(1 downto 0);
                    r_cfg_intl_mode <= i_config(2);
                    if (i_config(2) = '1') then
                        if (i_config(1 downto 0) = "11") then
                            r_cfg_col_count <= shift_left(r_cfg_col_count, 4);
                        else
                            r_cfg_col_count <= shift_left(r_cfg_col_count, 3);
                        end if;
                    else
                        if (i_config(1 downto 0) = "11") then
                            r_cfg_col_count <= shift_left(r_cfg_col_count, 1);
                        end if;
                    end if;
                end if;

                ---------------------------------------------------------------
                -- Stage 0
                ---------------------------------------------------------------
                r_s_valid   <= s_valid;
                r_s_data    <= s_data;
                r_s_sop     <= s_sop;
                r_s_eop     <= s_eop;
                -- frame counter based on eop
                if (s_eop = '1') then
                    r_sr_wf_count  <= r_sr_wf_count(22 downto 00) & r_sr_wf_count(23);
                end if;
                -- update write pointer when one interleaver matrix is full
                if (s_eop = '1' and (w_last_f_short = '1' or w_last_f_long = '1')) then -- expected CRITICAL
                    r_write_pnter_s0   <= r_write_pnter_s0 + 1;
                end if;

            else
                r_s_valid   <= '0';
                r_s_sop     <= '0';
                r_s_eop     <= '0';
            end if;


            ---------------------------------------------------------------
            -- Stage 1 - Updates on every clock cycle - flushes data to mem
            ---------------------------------------------------------------
            r_write_valid_s1      <= r_s_valid;
            r_write_data_s1       <= r_s_data;
            -- row
            if (r_s_valid = '1') then
                if (r_s_sop = '1') then
                    r_write_row_s1    <= (others => '0');
                else
                    if (r_write_row_s1 >= 31) then    -- +9 mod 40
                        r_write_row_s1    <= r_write_row_s1 - 31;
                    else
                        r_write_row_s1    <= r_write_row_s1 + 9;
                    end if;
                end if;
            end if;
            -- col
            if (r_s_valid = '1') then
                if ((w_first_f_short = '1' or w_first_f_long = '1') and r_s_sop = '1') then      -- TODO - reset at correct time
                    r_write_col_s1    <= (others => '0');
                else
                    if (r_write_row_s1 = 31) then    -- last row number
                        r_write_col_s1    <= r_write_col_s1 + 1;
                    end if;
                end if;
            end if;

            r_write_pnter_s1    <= r_write_pnter_s0;


            ---------------------------------------------------------------
            -- Stage 2 
            ---------------------------------------------------------------
            r_write_valid_s2    <= r_write_valid_s1;
            r_write_data_s2     <= r_write_data_s1;
            r_write_row_s2      <= r_write_row_s1;
            r_write_col_s2      <= resize(40 * r_write_col_s1, 14);
            r_write_pnter_s2    <= r_write_pnter_s1;

            ---------------------------------------------------------------
            -- Stage 3
            ---------------------------------------------------------------
            r_write_valid_s3    <= r_write_valid_s2;
            r_write_data_s3     <= r_write_data_s2;
            r_write_addr_s3     <= resize(r_write_row_s2 + r_write_col_s2, 14);
            r_write_pnter_s3    <= r_write_pnter_s2;

            ---------------------------------------------------------------
            -- Stage 4
            ---------------------------------------------------------------
            r_write_pnter_s4    <= r_write_pnter_s3;

            ---------------------------------------------------------------
            -------------------- READ LOGIC -------------------------------
            ---------------------------------------------------------------

            ---------------------------------------------------------------
            -- Stage 0
            ---------------------------------------------------------------
            if (m_ready = '1' and not w_intl_empty = '1') then
                -- read frame counter
                if (r_read_valid_s0 = '1' and r_read_row_s0 = 39 and r_sr_18_count(17) = '1' and (w_last_18_col = '1' or w_last_36_col = '1' or w_last_144_col = '1' or w_last_288_col = '1')) then
                    r_sr_18_count   <= (0 => '1', others => '0');
                elsif (r_read_valid_s0 = '1' and r_read_row_s0 = 39) then
                    r_sr_18_count   <= r_sr_18_count(r_sr_18_count'high-1 downto r_sr_18_count'low) & r_sr_18_count(r_sr_18_count'high);
                end if;
                if (r_read_valid_s0 = '1' and r_read_row_s0 = 39 and r_sr_18_count(17) = '1' and (w_last_18_col = '1' or w_last_36_col = '1' or w_last_144_col = '1' or w_last_288_col = '1')) then
                    r_sr_16_count   <= (0 => '1', others => '0');
                elsif (r_read_valid_s0 = '1' and r_read_row_s0 = 39 and r_sr_18_count(r_sr_18_count'high) = '1') then
                    r_sr_16_count   <= r_sr_16_count(r_sr_16_count'high-1 downto r_sr_16_count'low) & r_sr_16_count(r_sr_16_count'high);
                end if;

                --row
                if (r_read_row_s0 = 39 or (r_read_row_s0 = 0 and r_read_valid_s0 = '0')) then
                    r_read_row_s0   <= (others => '0');
                else
                    r_read_row_s0   <= r_read_row_s0 + 1;
                end if;

                -- col
                if (r_read_valid_s0 = '0' and r_read_row_s0 = 0) or (r_read_row_s0 = 39 and r_read_sop_s0 = '0' and r_sr_18_count(r_sr_18_count'high) = '1' and (w_last_18_col = '1' or w_last_36_col = '1' or w_last_144_col = '1' or w_last_288_col = '1')) then
                    r_read_col_s0   <= (others => '0');
                    r_read_col_last_row0    <= (others => '0');
                else
                    if (r_read_row_s0 = 39) then
                        r_read_col_s0 <= r_read_col_last_row0 + 1;
                        r_read_col_last_row0    <= r_read_col_last_row0 + 1;
                    elsif (r_read_col_s0 < 17) then
                        r_read_col_s0   <= r_read_col_s0 + r_cfg_col_count - 17;
                    else
                        r_read_col_s0   <= r_read_col_s0 - 17;
                    end if;
                end if;

                -- sop
                --if (r_read_row_s0 = 0 and r_sr_18_count(r_sr_18_count'low) = '1' and r_sr_16_count(r_sr_16_count'low) = '1') then
                if ((r_read_row_s0 = 39 and r_sr_18_count(17) = '1' and r_read_valid_s0 = '1' and w_last_intl_col = '1') 
                    or (r_read_valid_s0 = '0' and r_read_row_s0 = 0 and r_sr_18_count(r_sr_18_count'low) = '1' and r_sr_16_count(r_sr_16_count'low) = '1')) then
                    r_read_sop_s0   <= '1';
                else
                    r_read_sop_s0   <= '0';
                end if;

                -- eop
                if (r_read_row_s0 = 38 and r_sr_18_count(17) = '1' and (w_last_18_col = '1' or w_last_36_col = '1' or w_last_144_col = '1' or w_last_288_col = '1')) then
                    r_read_eop_s0   <= '1';
                else
                    r_read_eop_s0   <= '0';
                end if;

                if (w_last_intl_col = '1' and r_sr_18_count(17) = '1' and r_read_row_s0 = 39) then
                    r_read_valid_s0 <=  '0';
                else
                    r_read_valid_s0 <= '1';
                end if;

                if (r_read_eop_s0 = '1') then
                    r_read_pnter_s0 <= r_read_pnter_s0 + 1;
                end if;

            else
                r_read_sop_s0   <= '0';
                r_read_eop_s0   <= '0';
                r_read_valid_s0 <= '0';
            end if;

            ---------------------------------------------------------------
            -- Stage 1
            ---------------------------------------------------------------
            r_read_row_s1   <= r_read_row_s0;
            r_read_col_s1   <= resize(40 * r_read_col_s0, 14);
            r_read_valid_s1 <= r_read_valid_s0;
            r_read_sop_s1   <= r_read_sop_s0;
            r_read_eop_s1   <= r_read_eop_s0;
            r_read_pnter_s1 <= r_read_pnter_s0;

            ---------------------------------------------------------------
            -- Stage 2
            ---------------------------------------------------------------
            r_read_addr_s2  <= resize(r_read_row_s1 + r_read_col_s1, 14);
            r_read_valid_s2 <= r_read_valid_s1;
            r_read_sop_s2   <= r_read_sop_s1;
            r_read_eop_s2   <= r_read_eop_s1;
            r_read_pnter_s2 <= r_read_pnter_s1;

            ---------------------------------------------------------------
            -- Stage 3
            ---------------------------------------------------------------
            r_read_valid_s3 <= r_read_valid_s2;
            r_read_sop_s3   <= r_read_sop_s2;
            r_read_eop_s3   <= r_read_eop_s2;
            r_read_pnter_s3 <= r_read_pnter_s2;
    
            ---------------------------------------------------------------
            -- Stage 4 (Output Stage)
            ---------------------------------------------------------------
            r_m_read_valid  <= r_read_valid_s3;
            r_m_read_sop    <= r_read_sop_s3;
            r_m_read_eop    <= r_read_eop_s3;
            r_read_pnter_s4 <= r_read_pnter_s3;
            if (r_read_pnter_s3(0) = '0') then
                r_m_read_data   <= w_rdata_mem1;
            elsif (r_read_pnter_s3(0) = '1') then
                r_m_read_data   <= w_rdata_mem2;
            end if;

        end if;
    end process;

    MEM_PROC : process(i_clk)
    begin
        if rising_edge(i_clk) then
            -- write
            if r_write_valid_s3 = '1' then
                if r_write_pnter_s4(0) = '0' then
                    r_mem_1(to_integer(r_write_addr_s3))    <= r_write_data_s3;
                elsif r_write_pnter_s4(0) = '1' then
                    r_mem_2(to_integer(r_write_addr_s3))    <= r_write_data_s3;
                end if;
            end if;
            -- read
            r_raddr_mem1    <= r_read_addr_s2;
            r_raddr_mem2    <= r_read_addr_s2;
        end if;
    end process;

    w_rdata_mem1    <= r_mem_1(to_integer(r_raddr_mem1));
    w_rdata_mem2    <= r_mem_2(to_integer(r_raddr_mem2));



    ---------------------------------------------------------------
    -- Concurrent assignments
    ---------------------------------------------------------------
    w_first_f_short  <= '1' when (r_cfg_intl_mode = '0' and 
                                    (r_sr_wf_count(0) = '1' or 
                                     r_sr_wf_count(3) = '1' or 
                                     r_sr_wf_count(6) = '1' or 
                                     r_sr_wf_count(9) = '1' or 
                                     r_sr_wf_count(12) = '1' or
                                     r_sr_wf_count(15) = '1' or 
                                     r_sr_wf_count(18) = '1' or 
                                     r_sr_wf_count(21) = '1')
                          ) else '0';

    w_first_f_long   <= '1' when (r_cfg_intl_mode = '1' and r_sr_wf_count(0) = '1') else '0';

    -- count written packets : intl short: 3, intl long: 24
    w_last_f_short  <= '1' when (r_cfg_intl_mode = '0' and (r_sr_wf_count(2) = '1' or 
                                                            r_sr_wf_count(5) = '1' or 
                                                            r_sr_wf_count(8) = '1' or 
                                                            r_sr_wf_count(11) = '1' or 
                                                            r_sr_wf_count(14) = '1' or
                                                            r_sr_wf_count(17) = '1' or 
                                                            r_sr_wf_count(20) = '1' or 
                                                            r_sr_wf_count(23) = '1'))
                       else '0';
    w_last_f_long   <= '1' when (r_cfg_intl_mode = '1' and r_sr_wf_count(23) = '1') else '0';

    w_last_18_col   <= '1' when (r_cfg_bit_rate = "00" and r_cfg_intl_mode = '0') else '0';

    w_last_36_col   <= '1' when ((r_cfg_bit_rate = "11" and r_cfg_intl_mode = '0')
                            and (r_sr_16_count(1) = '1'))
                        else '0';

    w_last_144_col  <= '1' when (((r_cfg_intl_mode = '1') and (r_cfg_bit_rate = "00" or r_cfg_bit_rate = "01" or r_cfg_bit_rate = "10"))
                            and (r_sr_16_count(7) = '1'))
                          else '0';

    w_last_288_col  <= '1' when (r_cfg_bit_rate = "11" and r_cfg_intl_mode = '1' and r_sr_16_count(15) = '1') 
                          else '0';

    w_last_intl_col <= w_last_18_col or w_last_36_col or w_last_144_col or w_last_288_col;
    -- interleaver states
    w_intl_empty    <= '1' when (r_write_pnter_s0 = r_read_pnter_s0) else '0';
    w_intl_full     <= '1' when (r_write_pnter_s0(1) /= r_read_pnter_s0(1) and r_write_pnter_s0(0) = r_read_pnter_s0(0)) else '0';
    w_intl_half     <= '1' when (r_write_pnter_s0(0) /= r_read_pnter_s0(0)) else '0';
    -- other condition is invalid

    -- slave ready signal
    -- w_s_ready       <= '1' when (w_intl_empty = '1' or w_intl_half = '1') else '0';     -- write ready if interleaver is not full
    w_s_ready       <= '0' when w_intl_full = '1' else '1';

    -- output assignment
    s_ready         <= w_s_ready;
    m_valid         <= r_m_read_valid;
    m_data          <= r_m_read_data;
    m_sop           <= r_m_read_sop;
    m_eop           <= r_m_read_eop;

end architecture;
