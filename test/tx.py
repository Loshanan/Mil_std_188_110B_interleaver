from UART import UART
import constants

def main():

    bt = 150                # 150 bits per sec
    intl_str = "short"      # short interleaver setting
    bt_str = str(bt)

    # read input data from file
    in_file_name = f"../tb/sim_stim/{intl_str}_{bt_str}/in_{intl_str}_{bt_str}.csv"
    with open(in_file_name) as f:
        f.readline()            # discard first line
        data = [line.split(",")[0].strip() for line in f if line.strip()]
    bytestream = [("").join(data[i:i+8][::-1]) for i in range(0, len(data), 8)]

    uart = UART(baudrate=constants.baudrate)
    uart.send(bytestream)
    del uart

if __name__ == "__main__":
    main()
