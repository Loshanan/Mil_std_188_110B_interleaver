# This generates test vectors with constant, or with random binaries as interleaver input
import numpy as np
import pandas as pd
from read_addr import gen_read_order 
from write_addr import gen_write_order 
import os

bit_rates = [0, 1, 2, 3]        # 150, 300, 600, 1200
intl_modes = [0, 1]

def take_input():
    # bit rate
    rate_setting = input("Bit rate setting selection: \n 0: 150 bps (default), \n 1: 300bps, \n 2: 600bps, \n 3: 1200bps \nEnter the value: ")
    if not rate_setting:        # default
        rate_setting = "0"
    if rate_setting not in ("0", "1", "2", "3"):
        raise ValueError("Bit rate setting should be from 0 to 3 !!")
    bit_rate = int(rate_setting)

    # interleaver setting
    intl_setting = input("Interleaver setting selection: \n 0: short (default), \n 1: long \nEnter the value: ")
    if not intl_setting:        # default
        intl_setting = "0"
    if intl_setting not in ("0", "1"):
        raise ValueError("Interleaver setting should be 0 or 1 !!") 
    intl_len = int(intl_setting)
    
    intl_frame_count = input("Enter the number of interleaver output frames you need (default = 1): ")
    if not intl_frame_count:
        intl_frame_count = "1"
    if not intl_frame_count.isdigit() or int(intl_frame_count) == 0:
        raise ValueError("Frame count should be a positive interger !!")
    intl_frame_count = int(intl_frame_count)

    return bit_rate, intl_len, intl_frame_count


def main(bit_rate, intl_len, intl_frame_count, rand_seed):
        
    # parameter generation
    max_col = 18
    if bit_rate == 3:
        max_col *= 2
    if intl_len == 1:
        max_col *= 8
    
    if intl_len == 0:       # number of input frames per one output frame to be generated
        no_of_frames = 3 
    else:
        no_of_frames = 24

    fec_frame_len = 40 * max_col // no_of_frames       # size of the input frame (output of fec)
                                                        # output frame size is X3 of input for short interleaver and 
                                                        #                      X24         for long  interlever

    input_frames = []       # each frame in this array will fit into the interleaver based on its config
    for fcount in range(intl_frame_count):
        seed = rand_seed + fcount        # assigning different seeds for each intl frames
        rng = np.random.default_rng(seed)
        frame_in = np.zeros((40 * max_col, 3), dtype=int)

        # data bits
        tx_bits = rng.integers(0, 2, 40 * max_col)
        frame_in[:, 0]  = tx_bits

        # sop
        frame_in[::fec_frame_len, 1]  = 1
        # eop
        frame_in[fec_frame_len-1::fec_frame_len, 2] = 1

        input_frames.append(frame_in)


    # Interleaving process
    write_row_order, write_col_order = gen_write_order(max_col)
    read_row_order, read_col_order = gen_read_order(max_col)

    output_frames = []

    for frame_in in input_frames:
        frame_out = np.zeros((40 * max_col, 3), dtype=int)
        intl_matrix = np.zeros((40, max_col), dtype=int)
        for widx in range(len(write_row_order)):
            intl_matrix[write_row_order[widx], write_col_order[widx]] = frame_in[widx, 0]
        for ridx in range(len(read_row_order)):
            frame_out[ridx, 0] = intl_matrix[read_row_order[ridx], read_col_order[ridx]]
        # sop
        frame_out[ 0, 1] = 1
        frame_out[-1, 2] = 1

        output_frames.append(frame_out)

    return input_frames, output_frames

def save_to_file(bit_rate, intl_len, input_frames, output_frames):
    # write to file
    intl = "short" if intl_len == 0 else "long"
    rate = "150" if bit_rate == 0 else "300" if bit_rate == 1 else "600" if bit_rate == 2 else "1200"

    combined_in = np.vstack(input_frames)
    in_TV = pd.DataFrame(combined_in, columns=["data", "sop", "eop"])
    os.makedirs(f"../sim_stim/{intl}_{rate}", exist_ok=True)
    in_TV.to_csv(f"../sim_stim/{intl}_{rate}/in_{intl}_{rate}.csv", index=False)

    combined_out = np.vstack(output_frames)
    out_TV = pd.DataFrame(combined_out, columns=["data", "sop", "eop"])
    out_TV.to_csv(f"../sim_stim/{intl}_{rate}/out_{intl}_{rate}.csv", index=False)

if __name__ == "__main__":
    #bit_rate, intl_len, no_of_intl_frames = take_input()
    rand_seed = int(input("Enter the seed for random generation: "))
    no_frames = int(input("Enter the number of interleaver frames to generate: "))

    for br in bit_rates:
        for intl in intl_modes:
            input_frames, output_frames = main(br, intl, no_frames, rand_seed)
            save_to_file(br, intl, input_frames, output_frames)

    with open("seed", "w") as file:
        file.write("Seed used for the first interleaver frame: ")
        file.write(str(rand_seed))

