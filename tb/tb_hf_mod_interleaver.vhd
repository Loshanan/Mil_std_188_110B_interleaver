library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use std.textio.all;
use work.tb_avalon_st_driver_pkg.all;

entity tb_hf_mod_interleaver is
    generic (
        g_bit_rate    : natural := 150;
        g_intl_mode   : string  := "short";
        g_idle_clks   : integer := 2000;
        g_rand_ready  : boolean := false;
        g_rand_valid  : boolean := false
    );
end tb_hf_mod_interleaver;

architecture sim of tb_hf_mod_interleaver is

    constant c_clk_hz       : integer   := 300e6;
    constant c_clk_period   : time      := 1 sec / c_clk_hz;

    signal r_clk    : std_logic := '0';
    signal r_rstn   : std_logic := '0';

    constant stim_file   : string  := "tb/sim_stim/" & g_intl_mode & "_" & integer'image(g_bit_rate) & "/in_" & g_intl_mode & "_" & integer'image(g_bit_rate) & ".csv";
    constant ref_file    : string  := "tb/sim_stim/" & g_intl_mode & "_" & integer'image(g_bit_rate) & "/out_" & g_intl_mode & "_" & integer'image(g_bit_rate) & ".csv";
    constant log_file    : string  := "tb/sim_logs/log_" & g_intl_mode & "_" & integer'image(g_bit_rate) & ".csv";

    COMPONENT hf_mod_interleaver
    PORT (
        i_clk      : IN  std_logic;
        i_rstn     : IN  std_logic;
        i_soft_rst : IN  std_logic;
        s_ready    : OUT std_logic;
        s_valid    : IN  std_logic;
        s_data     : IN  std_logic;
        s_sop      : IN  std_logic;
        s_eop      : IN  std_logic;
        m_ready    : IN  std_logic;
        m_valid    : OUT std_logic;
        m_data     : OUT std_logic;
        m_sop      : OUT std_logic;
        m_eop      : OUT std_logic;
        i_config   : IN  std_logic_vector(2 downto 0)
    );
    END COMPONENT hf_mod_interleaver;

    SIGNAL w_ready    : std_logic;
    SIGNAL r_valid    : std_logic := '0';
    SIGNAL r_data     : std_logic := '0';
    SIGNAL r_sop      : std_logic := '0';
    SIGNAL r_eop      : std_logic := '0';
    SIGNAL r_ready    : std_logic := '1';
    SIGNAL w_valid    : std_logic;
    SIGNAL w_data     : std_logic;
    SIGNAL w_sop      : std_logic;
    SIGNAL w_eop      : std_logic;
    SIGNAL r_config   : std_logic_vector(2 downto 0) := "000";

    signal sim_done   : boolean   := false;
    signal write_done : boolean   := false;

    function f_gen_config(bit_rate : integer; intl_mode : string)
    return std_logic_vector is
        variable v_bit_rate   : std_logic_vector(1 downto 0);
        variable v_intl_mode  : std_logic;

    begin
        case bit_rate is
            when 150 =>
                v_bit_rate    := "00";
            when 300 =>
                v_bit_rate    := "01";
            when 600 =>
                v_bit_rate    := "10";
            when 1200 =>
                v_bit_rate    := "11";
            when others =>
                v_bit_rate    := "00";
        end case;

        if (intl_mode = "short") then
            v_intl_mode       := '0';
        elsif (intl_mode = "long") then
            v_intl_mode       := '1';
        else
            v_intl_mode       := '0';
        end if;

        return v_intl_mode & v_bit_rate ;
    end function f_gen_config;

begin

    r_clk <= not r_clk after c_clk_period / 2 when not write_done else '0';

    r_config    <= f_gen_config(g_bit_rate, g_intl_mode);

    P_SEQUENCER : process
    begin
        wait for c_clk_period * 50;

        r_rstn <= '1';

        wait for c_clk_period * 20;
        
        drive_avln_st(stim_file,
                      g_rand_valid,
                      r_clk, 
                      c_clk_period,
                      w_ready,
                      r_valid,
                      r_data,
                      r_sop,
                      r_eop);
        wait;

    end process;


    P_ST_MONITOR: process
    begin
        monitor_avln_st(
                    ref_file,
                    log_file,
                    sim_done,
                    write_done,
                    r_clk,
                    c_clk_period,
                    r_ready,
                    w_valid,
                    w_data,
                    w_sop,
                    w_eop
        );
        wait;

    end process P_ST_MONITOR;

    p_rnd_ready : process
        variable seed1        : positive  := 844;
        variable seed2        : positive  := 429;
        variable rand         : real;
        variable rand_int     : integer;
    begin
        r_ready     <= '0';
        wait until r_rstn = '1';
        wait for 25 * c_clk_period;

        if g_rand_ready then
            loop 
                uniform(seed1, seed2, rand);
                rand_int    := integer(10.0 * rand);
                for i in 0 to rand_int loop
                    wait until rising_edge(r_clk);
                end loop;
                r_ready     <= '1';

                uniform(seed1, seed2, rand);
                rand_int    := integer(10.0 * rand);
                for i in 1 to rand_int loop       -- 1 to rand range includes no delay as well
                    wait until rising_edge(r_clk);
                end loop;
                r_ready     <= '0';
            end loop;
        end if;

        r_ready   <= '1';
        wait;
    end process p_rnd_ready ;
    
    p_sim_timeout : process(r_clk)
        variable cap_count      : integer   := 0;
        variable waiting_clk    : integer   := 0;
        variable start_waiting  : boolean   := false;
    begin
        
        if rising_edge(r_clk) then
            if not start_waiting then
                if r_ready = '1' and w_valid = '1' then
                    start_waiting := true;
                    cap_count     := 1;
                end if;
            else
                waiting_clk     := waiting_clk + 1;
                if r_ready = '1' and w_valid = '1' then
                    cap_count   := cap_count + 1;
                    waiting_clk := 0;
                end if;
                if waiting_clk > g_idle_clks then
                    sim_done    <= true;
                    --report "Simulation Done!! ";
                    ---wait;
                    --assert false report "END of Simulation !! output idles out..." severity failure;
                end if;
            end if;
        end if;
    end process p_sim_timeout;

    p_compare_log: process
    begin
        ---wait until sim_done;
        wait until write_done = true;
        wait for 10 us;      -- let the logging finish
        compare_log_files(log_file, ref_file);
        --report "comparision done";
        wait;

    end process p_compare_log;

    hf_mod_interleaver_inst : hf_mod_interleaver
    PORT MAP (
        i_clk      => r_clk,
        i_rstn     => r_rstn,
        i_soft_rst => '0',
        s_ready    => w_ready,
        s_valid    => r_valid,
        s_data     => r_data,
        s_sop      => r_sop,
        s_eop      => r_eop,
        m_ready    => r_ready,
        m_valid    => w_valid,
        m_data     => w_data,
        m_sop      => w_sop,
        m_eop      => w_eop,
        i_config   => r_config
    );

end architecture;
