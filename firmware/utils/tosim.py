import sys
import os

boilerplate = """
// This file testprogram.js can be substituted by one of several tests
testprogramAddress=0x8000;  // where to load the test program

// we want to auto-clear the console if any output is sent by the program
var consoleboxStream="";

// demonstrate write hook
writeTriggers[0x3801]="consoleboxStream += String.fromCharCode(d);"+
                      "consolebox.innerHTML = consoleboxStream;";

// demonstrate read hook (not used by this test program)
readTriggers[0x8004]="((consolegetc==undefined)?0:0xff)";  // return zero until we have a char
readTriggers[0x8000]="var c=consolegetc; consolegetc=undefined; (c)";

// for opcodes, see http://www.textfiles.com/programming/CARDS/6800
testprogram = [
"""

filename = input("Filename: ")
createdText = boilerplate
with open(filename, 'rb') as f:
    filebytes = f.read()
    for i in range(0, len(filebytes)):
        createdText += "0x{:02x}".format(filebytes[i])
        if i != len(filebytes) - 1:
            createdText += ","
        if i % 16 == 15:
            createdText += "\n"
createdText += "];\n"

with open("testprogram.js", 'w') as f:
    f.write(createdText)


