# MIL\_STD\_188\_110B HF modem

## Interleaver Design in VHDL

## Board ZCU102 - TBD

## Motivation

In digital communication, errors are inavitable.  
Few types of erors are below:  

1) Random bit error

2) Burst error

e.t.c

Foward Error Correction (FEC) encoder and a dcoder is used to detect and correct the bit errors. But against the burst error the efficiency of FEC encoder is low.  
So, Interleaver is introduced in digital communication chain to mitigate the burst error.  

* After the FEC encoder interleaver do rearrange the data bits so that the consecutive data bits are apart.
* After deinterleaving the burst error caused by the channel would be scattered around the whole data block/frame.
* This scattered error can be effectively solved by FEC encoder

Types of interleaving techniques

1) Block interleaver

2) Convolusional interleaver

3) S-random interleaver

e.t.c

In this MIL\_STD\_188\_110B HF modem block interleaver was used with specific rearraching pattern, so block interleaving is focussed in this project.

## Functionality

The block interleaving method is used here.
And the interleaver has 0s, 0.6s, 4.8s interleaver settings.
Interleaver block size is based on this interleaver settings.

Two interleaver matrices are used, since from one interleaver, data can be fetched while other interleaver is in loading mode.
Currently only the following configureation is considered for this implementation.
bit rate - 150, 300, 600, 1200 bps
interleaver mode - short (0.6s), long (4.8s)

Interleaver block based on the configureation is following.

|   bit rate   | Long interleaver | Long interleaver | short interleaver | short interleaver |
|--------------|------------------|------------------|-------------------|-------------------|
|              | # of rows        | # of cols        | # of rows         | # of cols         |
|   1200       | 40               | 288              |   40              | 36                |
|   600        | 40               | 144              |   40              | 18                |
|   300        | 40               | 144              |   40              | 18                |
|   150        | 40               | 144              |   40              | 18                |

Note: 300 and 150 bit rates get the same block size as 600 since they use repeated coding. 300 has 1/4 coding rate and 150 has 1/8 coding rate while 600 (and 1200) has 1/2 coding rate.

## loading algorithm

--TODO: explain algo

* First stage(input stage) updates when both ready and valid are high
* Keeps valid low otherwise
* Every other stages updates on every active edge clk

## fetching algorithm

*python code for loading and fetching algorithm can be found in `tb/write_addr.py` and `tb/read_addr.py`

## Design decisions

* write pointer, and read pointers are considered as pointers to a fifo with data depth is 2.
* each pointer is 2 bit length since 1 bit is to point the address, and one extra to differentiate full and empty.
* The interleaver is empty when `write_pointer[1:0] = read_pointer[1:0]`
* The interleaver is full when `write_pointer[0] = read_pointer[0]` and `write_pointer[1] != read_pointer[1]`
* Interleaver is half full if `write_pointer[0] != read_pointer[0]` and `write_pointer[1] = read_pointer[1]`
* `write_pointer[0] != read_pointer[0]` and `write_pointer[1] != read_pointer[1]` is an invalid condition that should never occur
* TODO: SUMMARIZE ABOVE CONDITIONS IN A TABLE
* Config is sampled when whole interleaver is empty and the first sob is in.
* Bram memory is used with data width 1 bit.  
* See following ref that bram can be configured to 1bit: [amd_ref](https://docs.amd.com/r/en-US/ug573-ultrascale-memory-resources/Block-RAM-Summary)
* Interleaver matrices are stored into the BRAM as a single dimentioned array
* Address flattening happens columnwise to get use of the constant row count (40)

## Interface

avalon streaming is used as input and output
TODO: to be validated

* resetn, clk
* config - data rate (150, 300, 600, 1200 bps), interleaver mode(short, long)
* stream signals - rdreq, val, data, sob, eob

## Verification procedure



<!-- 

### Time logging
---------------
Started project on 03/Sep/2026  
03/Sep/2026 - Started Readme.md (~ 1hour)  
04/Sep/2026 - Continued Readme.md - refreshing the idea about funcitonality and making ready to start design work (~ 1hour)  
06/Sep/2026 - Architecture design start (write) (~ 0.5 hour)  
07/Sep/2026 - Architecture design (write) (~0.5 hour)  
09/Sep/2026 - Architecture design (write) (~ 1hour)  
10/Sep/2026 - Architecture design (write) (~ 0.5 hour)  
11/Sep/2026 - Architecture design (read) (~ 1.5 hour)  
13/Sep/2026 - Coding Done for write logic (~ 3 hour)  
14/Sep/2026 - Coding for read logic (~ 1 hour)  
16/Sep/2026 - Coding for read logic (~ 1.5 hour)  
17/Sep/2026 - Finish reading logic and started coding the mem (~ 1 hour)  
18/Sep/2026 - Finished coding mem and started tv gen script py (~1.5 hour)  
20/Sep/2026 - Started with ghdl, and gtkwave for simualtion (~1 hour)  
22/Sep/2026 - Test vector generation script in python (~1.5 hour)  
23/Sep/2026 - Researching about a testing environment (~1 hour)  
29/Sep/2026 - Started debugging waveform with gtkwave (~1 hour)  
02/Oct/2026 - single frame passing, debugging multi frames (~1.5 hour) 
03/Oct/2026 - Multi frame passing, debugging long interleaver mode (~3 hour)
04/Oct/2026 - Finished debugging, git init, more to test (~2 hour)

-->
