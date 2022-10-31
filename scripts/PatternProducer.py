# Script for generating input pattern file for the Phase-2 Finor Board.
# Developed  by Gabriele Bortolato (Padova  University)
# gabriele.bortolato@cern.ch

import numpy as np
import random
import argparse

from patternfiles import *
from bitstringconverter import *


parser = argparse.ArgumentParser(description='GT-Final OR board Pattern producer')
parser.add_argument('-i', '--indexes', metavar='N', type=int, default=1,
                    help='Number of algos to send')
parser.add_argument('-s', '--serenity', metavar='N', type=str, default='Serenity1',
                    help='Board to be tested')

args = parser.parse_args()
if args.serenity in ['Serenity1', 'Serenity2']:
    board = 'vu9p'
elif args.serenity == 'Serenity3':
    board = 'vu13p'



#################################### Pattern file Producer ################################
def prep_bitstring_data(data_int_new):
    # Step 1: convert data to integer representation
    data_int_new = convert_to_ap_ufixed(data_int_new, 64, 64)

    # Step 2: convert to bitstrings
    formatstring = np.full(1, "uint:64")
    data_bitstring = pack_vec(formatstring, data_int_new)

    # Step 3: Add required padding
    data_bitstring_padded = padd_vec(data_bitstring, 16)

    return data_bitstring_padded

def pattern_data_producer(indeces, positions, file_name, Links, debug):

    X_input_low = np.zeros((1017, 24), dtype=np.uint64)
    X_input_high = np.zeros((1017, 24), dtype=np.uint64)

    for i in range(len(indeces)):
        if indeces[i] < 576:
            offset = int(indeces[i] / 64)
            random_link = random.sample(range(24), 1)
            X_input_low[positions[i] * 9 + offset, random_link] = \
                X_input_low[positions[i] * 9 + offset, random_link] | np.uint64((1 << (indeces[i] - offset * 64)))
        else:
            offset = int((indeces[i] - 576) / 64)
            random_link = random.sample(range(24), 1)
            X_input_high[positions[i] * 9 + offset, random_link] = \
                X_input_high[positions[i] * 9 + offset, random_link] | np.uint64((1 << ((indeces[i] - 576) - offset * 64)))

    X_test_chunk = np.hstack((X_input_low, X_input_high))
    data_bitstring_padded = prep_bitstring_data(X_test_chunk)

    links = np.vstack((Links[0], Links[1]))
    # write out fname
    indir = "Pattern_files"
    fname = indir + "/" + file_name
    write_pattern_file(data_bitstring_padded, outputfile=fname, links=links.flatten())

    if debug:
        for row in range(3,12):
            f = open(fname, 'r')
            print(f.readlines()[row])




def pattern_producer_prescale_test(n_algo_bits, board='vu13p', debug=False):

    Possibile_indeces = range(1152)
    Possibile_rep     = range(int(1024 / 9))
    if board == 'vu9p':
        Available_links = [
            [44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75],
            [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]]
    # elif board == 'vu13p-slr021':
    # Availabe_links = [[36,37,38,39,40,41,42,43,44,45,46,47,80,81,82,83,84,85,86,87,88,89,90,91],
    #                  [4,5,6,7,8,9,10,11,12,13,14,15,112,113,114,115,116,117,118,119,120,121,122,123]]
    elif board == 'vu13p':
        Available_links = [
            [36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91],
            [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79]]

    indeces = random.sample(Possibile_indeces, n_algo_bits)
    repetitions = np.random.choice(Possibile_rep, size=n_algo_bits, replace=True)
    if debug:
        print("Algo bit indeces")
        print(np.array(indeces))
        print("Algo bit repetitions")
        print(np.array(repetitions))

    X_input_low = np.zeros((1017, 24), dtype=np.uint64)
    X_input_high = np.zeros((1017, 24), dtype=np.uint64)

    for i in range(len(indeces)):
        rep = random.sample(Possibile_rep, repetitions[i])
        if indeces[i] < 576:
            offset = int(indeces[i] / 64)
            for current_index in rep:
                random_link = random.sample(range(24), 1)
                X_input_low[current_index * 9 + offset, random_link] = X_input_low[
                                                                           current_index * 9 + offset, random_link] | np.uint64(
                    (1 << (indeces[i] - offset * 64)))
        else:
            offset = int((indeces[i] - 576) / 64)
            for current_index in rep:
                random_link = random.sample(range(24), 1)
                X_input_high[current_index * 9 + offset, random_link] = X_input_high[
                                                                            current_index * 9 + offset, random_link] | np.uint64(
                    (1 << ((indeces[i] - 576) - offset * 64)))

    X_test_chunk = np.hstack((X_input_low, X_input_high))
    data_bitstring_padded = prep_bitstring_data(X_test_chunk)

    links = np.vstack((Available_links[0], Available_links[1]))
    # write out fname
    indir = "Pattern_files"
    fname = indir + "/Finor_input_pattern_prescaler_test.txt"
    write_pattern_file(data_bitstring_padded, outputfile=fname, links=links.flatten())
    # save file for the simulation
    indir = "../simulation/firmware/hdl/"
    fname = indir + "/inputPattern.mem"
    write_pattern_file(data_bitstring_padded, outputfile=fname, links=links.flatten())
    # checking first frame
    if debug:
        for row in range(3, 12):
            f = open(fname, 'r')
            print(f.readlines()[row])

    return indeces, repetitions


def pattern_producer_trggmask_test(board='vu13p', debug=False):
    Possibile_rep = range(int(1024 / 9))
    N_trigg_masks = 8
    Algos_per_trigg = int(1152 / N_trigg_masks)

    algo_subset = np.random.choice(1152, [N_trigg_masks, Algos_per_trigg], replace=False)
    rep_per_trigg = np.random.choice(Possibile_rep, size=N_trigg_masks, replace=True)

    indeces = []
    positions = []



    for i in range(N_trigg_masks):
        algos_position = np.random.choice(Possibile_rep, size=rep_per_trigg[i], replace=False)
        algo_distrib = np.random.choice(algo_subset[i], size=rep_per_trigg[i], replace=True)
        indeces = np.int32(np.append(indeces, algo_distrib))
        positions = np.int32(np.append(positions, algos_position))
        # values, indexes, counts= np.unique(algo_distrib, return_counts=True, return_inverse=True)
        # print(values)
        # print(indexes)
        # print(counts)

    if debug:
        print("Replication per trigger")
        print(rep_per_trigg)
        print("Algo indeces")
        print(indeces)

    if board == 'vu9p':
        Available_links = [
            [44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75],
            [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]]
    # elif board == 'vu13p-slr021':
    # Availabe_links = [[36,37,38,39,40,41,42,43,44,45,46,47,80,81,82,83,84,85,86,87,88,89,90,91],
    #                  [4,5,6,7,8,9,10,11,12,13,14,15,112,113,114,115,116,117,118,119,120,121,122,123]]
    elif board == 'vu13p':
        Available_links = [
            [36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91],
            [48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79]]

    pattern_data_producer(indeces, positions, "Finor_input_pattern_trigg_test.txt", Available_links, debug)

    return algo_subset, rep_per_trigg

index,repetition = pattern_producer_prescale_test(args.indexes,board,False)

indir     = "Pattern_files"
fname     = indir + "/metadata/Prescaler_test/algo_rep.txt"
algo_data = np.vstack((index,repetition))
np.savetxt(fname, algo_data, fmt='%d')

trigg_index, trigg_rep = pattern_producer_trggmask_test(board,False)

indir     = "Pattern_files"
fname     = indir + "/metadata/Trigg_mask_test/trigg_index.txt"
np.savetxt(fname, trigg_index, fmt='%d')
fname     = indir + "/metadata/Trigg_mask_test/trigg_rep.txt"
np.savetxt(fname, trigg_rep, fmt='%d')
