-- Date: 28/09/2026
-- Author: Loshanan Mahalingam
-- Description: A common procedure for avalon streaming driver and monitor
-- TODO: make the procedure to support std_logic_vector data type (currently supports only std_logic)

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

use std.textio.all;

package tb_avalon_st_driver_pkg is
    procedure drive_avln_st(
        constant file_name  : in  string;
        constant rand_valid : in  boolean;
        signal clk          : in  std_logic;
        constant clk_period : in  time;
        signal ready        : in  std_logic;
        signal val          : out std_logic;
        signal data         : out std_logic;
        signal sop          : out std_logic; 
        signal eop          : out std_logic
    );
  
    procedure monitor_avln_st(
        constant ref_file_name  : in  string;
        constant out_file_name  : in  string;
        signal   sim_done       : in  boolean;
        signal write_done       : out boolean;
        -- constant const_valid: in  boolean;
        signal clk          : in std_logic;
        constant clk_period : in time;
        signal ready        : in std_logic;
        signal val          : in std_logic;
        signal data         : in std_logic;
        signal sop          : in std_logic; 
        signal eop          : in std_logic
    );

    procedure compare_log_files (
        constant log_file_name : in string;
        constant ref_file_name : in string
    );
end package tb_avalon_st_driver_pkg;



package body tb_avalon_st_driver_pkg is

    procedure drive_avln_st(

        constant file_name  : in  string;
        constant rand_valid : in  boolean;

        signal clk          : in  std_logic;
        constant clk_period : in  time;

        signal ready        : in  std_logic;
        signal val          : out std_logic;
        signal data         : out std_logic;
        signal sop          : out std_logic; 
        signal eop          : out std_logic

            ) is

        file in_file        : text;
        variable v_line     : line;
        variable v_data     : character;
        variable v_sop      : character;
        variable v_eop      : character;
        variable v_char     : character;
        
        -- for random
        variable seed1        : positive  := 289;
        variable seed2        : positive  := 561;
        variable rand         : real;
        variable rand_int     : integer;

        function char_to_std_logic(c : character) return std_logic is
        begin
            case c is
                when '0' =>
                    return '0';
                when '1' =>
                    return '1';
                when others =>
                    return 'X';
            end case;
        end function;
          
    begin
        
        file_open(in_file, file_name, read_mode);

        -- skip header
        readline(in_file, v_line);

        val   <= '0';
        data  <= '0';
        sop   <= '0';
        eop   <= '0';
        wait until rising_edge(clk);
        wait for 0.3 * clk_period;

        -- feed data
        while not endfile(in_file) loop
            readline(in_file, v_line);

            read(v_line, v_data);
            read(v_line, v_char);
            read(v_line, v_sop);
            read(v_line, v_char);
            read(v_line, v_eop);

            data    <= char_to_std_logic(v_data);
            sop     <= char_to_std_logic(v_sop);
            eop     <= char_to_std_logic(v_eop);
            val     <= '1';

            wait until rising_edge(clk) and ready = '1';
            wait for 0.3 * clk_period;
            val     <= '0';

            -- Random addition
            if rand_valid then
                uniform(seed1, seed2, rand);
                rand_int    := integer(6.0 * rand);
                for i in 1 to rand_int loop       -- 1 to rand range includes no delay as well
                    wait until rising_edge(clk);
                    wait for 0.3 * clk_period;
                end loop;
            end if;



        end loop;

        data    <= '0';
        sop     <= '0';
        eop     <= '0';

    end procedure drive_avln_st;

    procedure monitor_avln_st(
        constant ref_file_name  : in  string;
        constant out_file_name  : in  string;
        signal   sim_done       : in  boolean;
        signal write_done       : out boolean;
        -- constant const_valid: in  boolean;
        signal clk          : in std_logic;
        constant clk_period : in time;
        signal ready        : in std_logic;
        signal val          : in std_logic;
        signal data         : in std_logic;
        signal sop          : in std_logic; 
        signal eop          : in std_logic
    ) is
        file out_file       : text;
        variable v_line     : line;

        file ref_file       : text;
        variable v_ref      : line;
        variable v_data     : character;
        variable v_sop      : character;
        variable v_eop      : character;
        variable v_char     : character;
        variable v_match_count  : integer;

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
        file_open(out_file, out_file_name, write_mode);
        write(v_line, string'("data,sop,eop"));
        writeline(out_file, v_line);
        
        file_open(ref_file, ref_file_name, read_mode);
        readline(ref_file, v_ref);

        loop
            wait until rising_edge(clk);
            if (ready = '1' and val = '1') then
                write(v_line, std_logic_to_char(data));
                write(v_line, ',');
                write(v_line, std_logic_to_char(sop));
                write(v_line, ',');
                write(v_line, std_logic_to_char(eop));

                readline(ref_file, v_ref);
                read(v_ref, v_data);
                read(v_ref, v_char);
                read(v_ref, v_sop);
                read(v_ref, v_char);
                read(v_ref, v_eop);

                if not(v_data = std_logic_to_char(data) and v_sop = std_logic_to_char(sop) and v_eop = std_logic_to_char(eop)) then
                    assert false report "Value mismatch !!!!" severity error;
                else
                    v_match_count := v_match_count + 1;
                end if;

                writeline(out_file, v_line);
                --report("logged");

            end if;
            if sim_done then
                exit;
            end if;
        end loop;
        file_close(ref_file);
        file_close(out_file);

        write_done  <= true;
        wait;

    end procedure monitor_avln_st;


    procedure compare_log_files (
        constant log_file_name : in string;
        constant ref_file_name : in string
    ) is
        file log_file : text open read_mode is log_file_name;
        file ref_file : text open read_mode is ref_file_name;
    
        variable log_line : line;
        variable ref_line : line;
    
        variable log_data : character;
        variable log_sop  : character;
        variable log_eop  : character;
    
        variable ref_data : character;
        variable ref_sop  : character;
        variable ref_eop  : character;
    
        variable v_char   : character;

        variable line_num : integer := 0;
        variable errors   : integer := 0;
    
    begin

        --file_open(log_file, log_file_name, read_mode);
        --file_open(ref_file, ref_file_name, read_mode);
        --report "LOG FILE: " & log_file_name severity note;    
        --report "REF FILE: " & ref_file_name severity note;    

        -- Skip headers
        readline(log_file, log_line);
        readline(ref_file, ref_line);
    
        while not endfile(log_file) and not endfile(ref_file) loop
    
            line_num := line_num + 1;
            --report "line number: " & integer'image(line_num);
    
            readline(log_file, log_line);
            --report("log_line_len:" & integer'image(log_line'length));
            --report("log_line:" & log_line.all);
            -- Read log file
            read(log_line, log_data);
            --report("read data done ...");
            read(log_line, v_char);
            --report("read comma done ...");
            read(log_line, log_sop);
            --report("read sop done ...");
            read(log_line, v_char);
            --report("read comma done ...");
            read(log_line, log_eop);
            --report("read eop done ...");
            --report("log_data:" & log_data & ",log_sop:" & log_sop & ",log_eop:" & log_eop);
    
            readline(ref_file, ref_line);
            -- Read reference file
            read(ref_line, ref_data);
            read(ref_line, v_char);
            read(ref_line, ref_sop);
            read(ref_line, v_char);
            read(ref_line, ref_eop);
            --report("ref_data:" & ref_data & ",ref_sop:" & ref_sop & ",ref_eop:" & ref_eop);
    
            -- Compare
            if (log_data /= ref_data) or
               (log_sop  /= ref_sop)  or
               (log_eop  /= ref_eop) then
    
                errors := errors + 1;
    
                report "Mismatch at line " & integer'image(line_num)
                    & " | LOG: "
                    & log_data & ","
                    & log_sop  & ","
                    & log_eop
                    & " | REF: "
                    & ref_data & ","
                    & ref_sop  & ","
                    & ref_eop
                    severity error;
            end if;
    
        end loop;
    
        -- Check if one file has extra lines
        if not endfile(log_file) then
            report "ERROR: log_file contains additional data after line "
                & integer'image(line_num)
                severity error;
        elsif not endfile(ref_file) then
            report "ERROR: ref_file contains additional data after line "
                & integer'image(line_num)
                severity error;
        end if;
    
        -- Final result
        if errors = 0 then
            report "PASS: Log file matches reference file."
                severity note;
        else
            report "FAIL: " & integer'image(errors)
                & " mismatches found."
                severity error;
        end if;
    
    end procedure;
end package body tb_avalon_st_driver_pkg;
