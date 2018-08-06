#!/usr/bin/env python3
import os
import struct
from pathlib import Path

HEADER_SIZE = 2048 # This is the size of the redundant information between the start of the file and the first set of image information
HEADER_MAGIC = b'BOOT_IMAGE_RLE' # This is present at the start of the raw_resources.bin file
HEADER_MAGIC_SIZE = len(HEADER_MAGIC) # This is simply the number of bytes used in the HEADER_MAGIC - used to correctly move to the end of the header
IMAGE_INFO_SIZE = 64 # The number of bytes used to store the data values for each image

"""
The format for the image data:
40 bytes for the name (with the unused space taken up with a 0 as the byte value)
3 bytes for offset
3 bytes for size
3 bytes for width
3 bytes for height
3 bytes for posX
3 bytes for posY
6 (1 between each data value)
The bytes are done in the opposite way to usual - The first has the least significant value
"""

def printhex(name, val):
    print(name + ":", val)
    print("\thex:", hex(val))


class image: # Class to store the information of the image and print it when needed
    def __init__(self, name, offset, size, width, height, posX, posY):
        self.name = name
        self.offset = offset
        self.size = size
        self.width = width
        self.height = height
        self.posX = posX
        self.posY = posY

    def printStats(self):
        print("name:", self.name)
        printhex("offset", self.offset)
        printhex("size", self.size)
        printhex("width", self.width)
        printhex("height", self.height)
        printhex("posX", self.posX)
        printhex("posY", self.posY)


def extractImageInfo(imgInfo, raw_Data):
    nameList = [] # Simple loop to add the bytes for the name into a list - breaks at the first 0 or when the 40 allocated bytes have been searched
    for byteData in range(40):
        if imgInfo[byteData] == 0:
            break
        nameList.append(imgInfo[byteData])
    name = (bytes(nameList)).decode() # Takes the bytes in the list, converts it back to raw bytes and then decodes it into a string
    offset = imgInfo[40] + (imgInfo[41] * 256) + (imgInfo[42] * 65536)
    #print(imgInfo[40], imgInfo[41], imgInfo[42])
    size = imgInfo[44] + (imgInfo[45] * 256) + (imgInfo[46] * 65536)
    width = imgInfo[48] + (imgInfo[49] * 256) + (imgInfo[50] * 65536)
    height = imgInfo[52] + (imgInfo[53] * 256) + (imgInfo[54] * 65536)
    posX = imgInfo[56] + (imgInfo[57] * 256) + (imgInfo[58] * 65536)
    posY = imgInfo[60] + (imgInfo[61] * 256) + (imgInfo[62] * 65536)

    myimg = image(name, offset, size, width, height, posX, posY)
    myimg.printStats()
    outputFiles(myimg, raw_Data)


def outputFiles(myimg, raw_Data):
    relevantdata = raw_Data[myimg.offset:myimg.offset + myimg.size]
    rawfile = "out/raw/{}".format(myimg.name) + ".data"
    with open(rawfile, 'wb') as newFile:
        newFile.write(relevantdata)
    flippedfile = "out/flipped/{}".format(myimg.name) + ".rle.data"
    with open(rawfile, "rb") as old, open(flippedfile, "wb") as new:
        for chunk in iter(lambda: old.read(4), b""):
            chunk = struct.pack("<f", struct.unpack(">f", chunk)[0])
            new.write(chunk)

if __name__ == '__main__':

    inFile = "raw_resources.bin"

    if not (Path(inFile).is_file()):
        print("Error:", inFile, "is not a file.")
        exit()
    with open(inFile, "rb") as rr:
        raw_Data = rr.read()
        rr.seek(0)
        byte = rr.read(HEADER_MAGIC_SIZE)
        if (byte != HEADER_MAGIC):
            print("Error: The file you supplied is not a valid raw_resources image.")
            exit()
        # consume the whitespace
        if not os.path.exists('./out'):
            os.makedirs('./out')
        if not os.path.exists('./out/raw'):
            os.makedirs('./out/raw')
        if not os.path.exists('./out/flipped'):
            os.makedirs('./out/flipped')
        byte = rr.read(HEADER_SIZE - HEADER_MAGIC_SIZE)

        while True:
            imgInfo = bytearray(rr.read(IMAGE_INFO_SIZE)) # Reads the image info for one image (and subsequently moves the read head to the start of the next one)
            if (imgInfo[0] == 0): # Reached the end of the image info
                break
            extractImageInfo(imgInfo, raw_Data)
