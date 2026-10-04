-- Date: 28/09/2026
-- Author: Loshanan Mahalingam
-- Description: A common procedure for avalon streaming driver and monitor
-- TODO: make the procedure to support std_logic_vector data type (currently supports only std_logic)

library ieee;
use ieee.std_logic_1164.all;

use std.textio.all;

package tb_avalon_st_driver_pkg is
    procedure drive_avln_st(
        constant file_name  : in  string;
        -- constant const_valid: in  boolean;
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
        -- constant const_valid: in  boolean;
        signal clk          : in std_logic;
        constant clk_period : in time;
        signal ready        : in std_logic;
        signal val          : in std_logic;
        signal data         : in std_logic;
        signal sop          : in std_logic; 
        signal eop          : in std_logic
    );
end package tb_avalon_st_driver_pkg;



package body tb_avalon_st_driver_pkg is

    procedure drive_avln_st(

        constant file_name  : in  string;
        -- constant const_valid: in  boolean;

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
        end loop;

        data    <= '0';
        sop     <= '0';
        eop     <= '0';

    end procedure drive_avln_st;

    procedure monitor_avln_st(
        constant ref_file_name  : in  string;
        constant out_file_name  : in  string;
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
        
        loop
            wait until rising_edge(clk);
            if (ready = '1' and val = '1') then
            write(v_line, std_logic_to_char(data));
            write(v_line, ',');
            write(v_line, std_logic_to_char(sop));
            write(v_line, ',');
            write(v_line, std_logic_to_char(eop));
            writeline(out_file, v_line);
            --report("logged");
            end if;
        end loop;
        
        wait;

    end procedure monitor_avln_st;
end package body tb_avalon_st_driver_pkg;
