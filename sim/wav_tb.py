import cocotb
from cocotb.triggers import RisingEdge, Timer
import random

import wave

async def generate_clock(dut):
    """ generate clock pulses """
    while True:
        dut.clk_in.value = 0
        await Timer(5,units="ns")
        dut.clk_in.value = 1
        await Timer(5,units="ns")

async def reset(dut):
    dut.rst_in.value = 1
    await Timer(10,units="ns")
    dut.rst_in.value = 0
    await Timer(10,units="ns")
    
        
async def deliver_byte(dut,data,cycles_rest):
    """ put a byte on the input wires with proper valid signal
        followed by appropriate number of rest cycles
    """
    dut.wavbyte_valid_in.value = 1
    dut.wavbyte_in.value = data
    await Timer(10,units="ns")
    dut.wavbyte_valid_in.value = 0
    await Timer(10*cycles_rest,units="ns")

async def track_returned_values(dut, responses):
    while True:
        await RisingEdge(dut.clk_in)
        if (dut.sample_valid_out.value == 1):
            responses["returned_values_count"] += 1
            responses["returned_values"].append( dut.sample_out.value )
                
    
@cocotb.test()
async def test_a(dut):
    """ test on real wav file"""

    await cocotb.start( generate_clock(dut) )
    await reset(dut)

    responses = {"returned_values_count":0, "returned_values":bytearray()}
    await cocotb.start(track_returned_values(dut,responses))

    with open("test.wav", mode="rb") as wavfile:
        byte = wavfile.read(1)
        while byte != b"":
            await deliver_byte(dut,int.from_bytes(byte,"big"),2)
            # print(hex(int.from_bytes(byte,"little")),byte)
            byte = wavfile.read(1)
    # await deliver_byte(dut,int.from_bytes(b'R',"little"),1)
    await Timer(50,units="ns")
    print(responses["returned_values_count"])


    with wave.open("test.wav") as wavfile_encoded:
        metadata = wavfile_encoded.getparams()
        frames = wavfile_encoded.readframes( metadata.nframes )

        print( frames[0], responses["returned_values"][0] )

        assert metadata.nframes == responses["returned_values_count"]
        assert frames == responses["returned_values"]
    
    print("done")


