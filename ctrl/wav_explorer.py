import wave

with wave.open("mono8.wav") as wav_file:
    metadata = wav_file.getparams()
    frames = wav_file.readframes(metadata.nframes)
    print(metadata.nframes)
    # print(bytearray(frames))

def identify_chunk(fp):
    name = fp.read(4)
    length = int.from_bytes( fp.read(4), "little" )
    return (name,length)
    
with open("mono8.wav", mode="rb") as plain_wav:
    # for n in range(80):
    #     b = plain_wav.read(2)
    #     i = int.from_bytes(b,"little")
    #     print(n*2,b,i, hex(i))
    # RIFF
    rd = plain_wav.read(4)
    print(rd)
    # filesize
    rd = plain_wav.read(4)

    print( "filesize", int.from_bytes(rd,"little") )

    # WAVE
    rd = plain_wav.read(4)
    print(rd)

    frames = bytearray()

    chunk_name,chunk_length = identify_chunk(plain_wav)
    while (chunk_length != 0):
        print(chunk_name,chunk_length)
        if (chunk_name == b'data'):
            for i in range(chunk_length):
                datum_byte = plain_wav.read(1)
                datum = int.from_bytes( datum_byte, "little" )
                frames.append(datum)
                # print(datum)
        else:
            for i in range(chunk_length):
                plain_wav.read(1)
        chunk_name,chunk_length = identify_chunk(plain_wav)

    print(frames)

        
    
        
    
