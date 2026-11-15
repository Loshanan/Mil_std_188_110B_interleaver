import serial

class UART:
    def __init__(self, port="/dev/ttyUSB1", baudrate=115200, timeout=1):
        self.port = port
        self.baudrate = baudrate
        self.bytesize = serial.EIGHTBITS
        self.parity = serial.PARITY_NONE
        self.stopbits = serial.STOPBITS_ONE
        self.timeout = timeout

        self.ser = serial.Serial(
            port=self.port,
            baudrate=self.baudrate,
            bytesize=self.bytesize,
            parity=self.parity,
            stopbits=self.stopbits,
            timeout=self.timeout,
        )

    def send(self, message):
        '''
            expecting message as array of binary strings
        '''
        data = bytes(int(m, 2) for m in message)
        print(f"Sending {len(data)} bytes")
        self.ser.write(data)

    def receive(self, file_name):
        f = open(file_name, "w")
        f.write("data\n")
        read_data = ""
        try:
            while True:
                chunk  = self.ser.read(self.ser.in_waiting or 1)
                for b in chunk:
                    #f.write(f"{b:08b}\n")
                    f.write("\n".join(f"{b:08b}"[::-1]) + "\n")
                    print(f"Received: {b:08b}")
                    #print("char", chr(b))
                    #print("dec", b, "; hex:", f"{b:02X}", "; bin:", f"{b:08b}")
                f.flush()

        except KeyboardInterrupt:
            f.flush()
            f.close()

    def __del__(self):
        self.ser.close()
        print("Serial device closed!")


