# Small library designed to write and read pattern files from numpy arrays.
# Developed by Ihor     Komarov   (Hamburg University) 
# Modified  by Gabriele Bortolato (Padova  University)

import numpy as np


##########################
## Pattern file writing ##
##########################

# Function creating header needed for patter file
# The lengths vector is used to determine the number of links as well as their width
def header(ID, lengths, links=[0]):
    txt = "ID: " + ID + "\n"
    txt += "Metadata: (strobe,) start of orbit, start of packet, end of packet, valid\n"
    
    j = 0
    i = links[j]
    txt += "\n      Link    "
    j = 0
    i = links[j]
    for characters in lengths:
        i = links[j]
        txt += ' ' * int((characters + 4)/ 2)
        txt += '{:03d}'.format(i)
        txt += ' ' * int((characters + 4) / 2)
        if (characters % 2 != 0): txt += ' '
        j += 1

    txt += "\n"
    return txt


# Writing pattern file lines from numpy array of bitstrings
# TODO: Currently, the 'valid' bin is not used. If decided how to use it, this needs to be changed
def body(metadata, data):
    txt = ""
    iframe = 0
    for data_line in zip(metadata,data):
        txt += 'Frame {:04d}   '.format(iframe)
        for metavalue, value in zip(data_line[0],data_line[1]):
            bits = metavalue
            start_of_orbit = bits[0]*1
            start          = bits[1]*1
            last           = bits[2]*1
            valid          = bits[3]*1
            txt += ' ' + start_of_orbit + start + last + valid + ' '
            txt += value + ' '
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
def write_pattern_file(metadata, data, boardname="x0", outputfile="pattern.txt", links=0):
    f = open(outputfile, 'w')

    # Writing header
    f.write(header(boardname, len_vec(data[0]), links))
    # Writing body
    f.write(body(metadata, data))

    f.close()


##########################
## Pattern file reading ##
##########################

# function parsing a pattern file and outputting the content as a numpy array
def read_pattern_file(filename, keepInvalid=False):
    print("Parsing " + filename + "...")
    with open(filename) as f:

        # Crosscheck whether this has the structure of a pattern file
        line = f.readline()  # this should be the "ID XXXX" line
        if (line.find("ID") == -1):
            raise NameError("Not a pattern file!")
        else:
            print("Found ID: " + line.split(" ", 1)[1].rstrip('\n'))
        line = f.readline()  # this should be the "Metadata" line
        if (line.find("Metadata") == -1):
            raise NameError("Not a pattern file!")
        line = f.readline()  # this should be empty
        line = f.readline()  # this should be the "Link" line
        if (line.find("Link") == -1):
            raise NameError("Not a pattern file!")
        else:
            tempstring = line.split()[1:]
            col_count = len(tempstring)
            print("Found " + str(col_count) + " links.")
            links = [int(element) for element in tempstring]

        i = 0
        line = f.readline()  # this should be the first content line
        valid_arr = []
        data_arr = []
        while line:
            tempstring = line.split()[2:]
            # tempstring = line.split(": ", 1)[1].rstrip('\n')
            linearray = np.array(tempstring)
            data_str = linearray[1::2]  # take only odd elements
            metadata_str = linearray[::2]  # take only even elements
            metadata = [int(element.replace('U','0'), 2) for element in metadata_str]
            temp_valid_arr = np.bitwise_and([1], np.array(metadata))
            valid_arr = np.append(valid_arr, temp_valid_arr)
            temp_data_arr = np.uint64([int(element, 16) for element in data_str])
            data_arr.append(temp_data_arr)
            line = f.readline()
            i += 1

        data_arr = np.array(data_arr)
        valid_arr = np.array(np.reshape(valid_arr, (i, len(links))), dtype=np.uint64)
        data_arr  = np.array(np.reshape(data_arr, (i, len(links))), dtype=np.uint64)

    return valid_arr.T,  data_arr.T, np.array(links)


def find_valid_bit(strings):
    return np.array([string[0:2] == "1v" for string in strings])


def remove_validity_bit(strings):
    return np.array([string[2:] for string in strings])
