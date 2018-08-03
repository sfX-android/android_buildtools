#!/usr/bin/env python3
import sys
import codecs
import os
from pathlib import Path

HEADER_SIZE = 0x800
HEADER_MAGIC = b'BOOT_IMAGE_RLE'
HEADER_MAGIC_SIZE = 14
IMAGE_INFO_SIZE = 64


def printUsage():
    print("rawresources.py <extract> raw_resources.bin")
    exit()


def printhex(name, val):
    print(name + ":", val)
    print("\thex:", hex(val))


class image:
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
    name = ""
    offset = imgInfo[40] + (imgInfo[41] * 0x100) + (imgInfo[42] * 0x10000)
    size = imgInfo[44] + (imgInfo[45] * 0x100) + (imgInfo[46] * 0x10000)
    width = imgInfo[48] + (imgInfo[49] * 0x100) + (imgInfo[50] * 0x10000)
    height = imgInfo[52] + (imgInfo[53] * 0x100) + (imgInfo[54] * 0x10000)
    posX = imgInfo[56] + (imgInfo[57] * 0x100) + (imgInfo[58] * 0x10000)
    posY = imgInfo[60] + (imgInfo[61] * 0x100) + (imgInfo[62] * 0x10000)
    while True:
        imgInfoHex = codecs.encode(imgInfo, 'hex')
        name = bytearray.fromhex(imgInfoHex.decode().split("00")[0]).decode()
        break

    myimg = image(name, offset, size, width, height, posX, posY)
    myimg.printStats()
    outputFiles(myimg, raw_Data)


def outputFiles(myimg, raw_Data):
    relevantdata = raw_Data[myimg.offset:myimg.offset + myimg.size]
    with open("out/raw/{}".format(myimg.name), 'wb') as newFile:
        newFile.write(relevantdata)
    flipped = flipEndianness(relevantdata)
    with open("out/flipped/{}".format(myimg.name), 'wb') as newFile:
        newFile.write(flipped)


def flipEndianness(binary):
    dataList = list(binary)
    flipped = []
    for dataByte in range(0, len(dataList), 2):
        flipped.insert(0, dataList[dataByte])
        flipped.insert(1, dataList[dataByte + 1])
    return bytes(flipped)


if (len(sys.argv) != 3):
    printUsage()

if (sys.argv[1] == "extract"):
    inFile = sys.argv[2]

    if not (Path(inFile).is_file()):
        print("Error:", inFile, "is not a file.")
        printUsage()
    with open(inFile, "rb") as rr:
        raw_Data = rr.read()
        rr.seek(0)
        byte = rr.read(HEADER_MAGIC_SIZE)
        if (byte != HEADER_MAGIC):
            print("Error: The file you supplied is not a valid raw_resources image.")
            printUsage()
        # consume the whitespace
        if not os.path.exists('./out'):
            os.makedirs('./out')
        if not os.path.exists('./out/raw'):
            os.makedirs('./out/raw')
        if not os.path.exists('./out/flipped'):
            os.makedirs('./out/flipped')
        byte = rr.read(HEADER_SIZE - HEADER_MAGIC_SIZE)

        while True:
            imgInfo = bytearray(rr.read(IMAGE_INFO_SIZE))
            imgInfo = codecs.encode(imgInfo, 'hex')
            if (imgInfo.startswith(b'00')):
                break
            extractImageInfo(bytearray(codecs.decode(imgInfo, 'hex')), raw_Data)
