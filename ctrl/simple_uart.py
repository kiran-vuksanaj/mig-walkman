import serial
import time

ser = serial.Serial("/dev/ttyUSB1",9600)

ser.write(bytearray('ABCD','ascii'))
time.sleep(3)
ser.write(bytearray("Hi",'ascii'))
