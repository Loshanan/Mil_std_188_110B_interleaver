from UART import UART
import constants

def main():

    bt = 150                # 150 bits per sec
    intl_str = "short"      # short interleaver setting
    bt_str = str(bt)

    # read input data from file
    out_file_name = f"../tb/board_logs/bd_{intl_str}_{bt_str}.csv"

    uart = UART(baudrate=constants.baudrate)
    uart.receive(out_file_name)
    del uart

if __name__ == "__main__":
    main()
