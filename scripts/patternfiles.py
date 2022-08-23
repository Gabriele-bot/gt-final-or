# Small library designed to write and read patter files from numpy arrays.

import numpy as np


#########################
## Patter file writing ##
#########################

# Function creating header needed for patter file
# The lengths vector is used to determine the number of links as well as their width
def header(boardname, lengths, links=[0]):
    txt = "Board " + boardname + "\n"
    txt += " Quad/Chan : "
    j = 0
    i = links[j]
    for characters in lengths:
        i = links[j]
        characters = characters - 2
        txt += ' ' * int(characters / 2)
        txt += 'q{:02d}c{}'.format(i // 4, i % 4)
        txt += ' ' * int(characters / 2)
        if (characters % 2 != 0): txt += ' '
        j += 1

    txt += "\n      Link : "
    j = 0
    i = links[j]
    for characters in lengths:
        i = links[j]
        txt += ' ' * int(characters / 2)
        txt += '{:03d}'.format(i)
        txt += ' ' * int(characters / 2)
        if (characters % 2 != 0): txt += ' '
        j += 1

    txt += "\n"
    return txt


# Writing pattern file lines from numpy array of bitstrings
# TODO: Currently, the 'valid' bin is not used. If decided how to use it, this needs to be changed
def body(data):
    txt = ""
    iframe = 0
    for data_line in data:
        txt += 'Frame {:04d} :'.format(iframe)
        for value in data_line:
            v = "1"  # TODO set v
            txt += ' ' + v + 'v'
            txt += value
        txt += ' \n'
        iframe += 1
    return txt


# need vectorized len for header
def len_vec(data):
    return np.array([len(val) for val in data])


# Writer for a pattern file, taking a numpy array of data as input
# The desired format is given in formatstring as a numpy array of strings
# Use linkOffset to specify the number of the first link to be used
# Use padding to define a fixed length of string (will crash if too small, use 0 for no padding)
# Attention: this is defined WITHOUT the validity bit!
def write_pattern_file(data, boardname="x0", outputfile="pattern.txt", links=0):
    f = open(outputfile, 'w')

    # Writing header
    f.write(header(boardname, len_vec(data[0]), links))
    # Writing body
    f.write(body(data))

    f.close()


#########################
## Patter file reading ##
#########################

# function parsing a pattern file and outputting the content as a numpy array
def read_pattern_file(filename, keepInvalid=False):
    print("Parsing " + filename + "...")
    with open(filename) as f:

        # Crosscheck whether this has the structure of a pattern file
        line = f.readline()  # this should be the "Board XXXX" line
        if (line.find("Board") == -1):
            raise NameError("Not a pattern file!")
        else:
            print("Found board: " + line.split(" ", 1)[1].rstrip('\n'))
        line = f.readline()  # this should be the "Quad/Chan" line
        if (line.find("Quad/Chan") == -1): raise NameError("Not a pattern file!")
        line = f.readline()  # this should be the "Link" line
        if (line.find("Link") == -1):
            raise NameError("Not a pattern file!")
        else:
            tempstring = line.split(": ", 1)[1]
            tempstring = ' '.join(tempstring.split())
            col_count = len(tempstring.split(" "))
            print("Found " + str(col_count) + " links.")

        line = f.readline()  # this should be the first content line
        linearrays = []
        while line:
            tempstring = line.split(": ", 1)[1].rstrip('\n')  # [:-1] TODO fix this, should strip final spaces as well
            linearray = np.array(tempstring.split(" "))
            if (np.all(find_valid_bit(linearray)) or keepInvalid):  # skipping lines with invalid bits
                linearrays.append(remove_validity_bit(linearray))  # stripping the validity bits
            line = f.readline()
    return np.array(linearrays)


def find_valid_bit(strings):
    return np.array([string[0:2] == "1v" for string in strings])


def remove_validity_bit(strings):
    return np.array([string[2:] for string in strings])
