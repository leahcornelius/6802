# Quick script that opens a raw binary file
# for each byte it sets the first 2 bits to 0 (keep the last 6 bits as they are)
# and writes the result to a new file (also raw binary)

import sys

filename = sys.argv[1]
newfilename = sys.argv[2]
data = open(filename, "rb").read()
newdata = b""
for byte in data:
    newdata += bytes([byte & 0b00111111])

open(newfilename, "wb").write(newdata)
