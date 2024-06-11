import serial


ser = serial.Serial("/dev/ttyUSB1",57600)
print("UART established")

print("Beginning file transmission")
with open("audio.wav", mode="rb") as wavfile:
    byte = wavfile.read(1)
    while byte != b"":
    # for cycle in range(100):
        ser.write( byte )
        # input() # step through one byte at a time
        byte = wavfile.read(1)

print("File transmitted")
