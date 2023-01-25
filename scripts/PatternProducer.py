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
    data_bitstring = pack_vec(formatstring, data_int_new, 'hex')

    # Step 3: Add required padding
    data_bitstring_padded = padd_vec(data_bitstring, 16)

    return data_bitstring_padded
    
def prep_bitstring_metadata(metadata_int_new):

    	
    metadata_bitstring = pack_vec('uint:4', metadata_int_new, 'bin')

    return metadata_bitstring


def extract_random_indexes(n_algo_bits, max_algos=1152, max_rep=113, low_rep=True, debug=False):

    Possibile_indeces = range(max_algos)
    Possibile_rep = range(int(max_rep))

    indeces = random.sample(Possibile_indeces, n_algo_bits)
    end_point = 25
    p = np.exp(-np.arange(0, end_point, end_point / 112.0))
    p = np.insert(p, 0, 0)
    p_norm = p / p.sum()

    if low_rep:
        repetitions = np.random.choice(Possibile_rep, size=n_algo_bits, replace=True, p=p_norm)
    else:
        repetitions = np.random.choice(Possibile_rep, size=n_algo_bits, replace=True)

    if debug:
        print("Algo bit indeces")
        print(np.array(indeces))
        print("Algo bit repetitions")
        print(np.array(repetitions))

    algo_matrix = np.zeros((max_algos, max_rep), bool)

    for rep, index in zip(repetitions, indeces):
        random_spot = np.random.choice(Possibile_rep, size=rep, replace=False)
        for i in random_spot:
            algo_matrix[index, i] = True

    return algo_matrix, indeces, repetitions


def get_Available_links(board):

    if board == 'vu9p':
        Available_links = [
            [44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75],
            [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115]]
    # elif board == 'vu13p-slr021':
    # Availabe_links = [[36,37,38,39,40,41,42,43,44,45,46,47,80,81,82,83,84,85,86,87,88,89,90,91],
    #                  [4,5,6,7,8,9,10,11,12,13,14,15,112,113,114,115,116,117,118,119,120,121,122,123]]
    elif board == 'vu13p':
        Available_links = [
            [127,126,125,124,123,122,121,120,119,118,117,116,11,10,9,8,7,6,5,4,3,2,1,0],
            [91,90,89,88,87,86,85,84,83,82,81,80,47,46,45,44,43,42,41,40,39,38,37,36]]
    else:
        raise Exception("Board not valid, choose in ['vu13p', 'vu9p']")

    return Available_links



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


def pattern_data_producer_v2(algo_matrix, file_name, Links, debug, for_sim=False):

    X_input_low  = np.zeros((1024, 24), dtype=np.uint64)
    X_input_high = np.zeros((1024, 24), dtype=np.uint64)

    Possibile_rep     = np.array(range(int(1024 / 9)))
    Possibile_indeces = np.array(range(1152))
    index_mask = np.logical_or.reduce(algo_matrix, 1).astype(bool)
    indeces = Possibile_indeces[index_mask]

    for i in range(len(indeces)):
        postition_mask = algo_matrix[indeces[i], :]
        positions = Possibile_rep[postition_mask]
        if indeces[i] < 576:
            offset = int(indeces[i] / 64)
            random_link = random.sample(range(24), 1)
            X_input_low[positions * 9 + offset, random_link] = \
                X_input_low[positions * 9 + offset, random_link] | np.uint64((1 << (indeces[i] - offset * 64)))
        else:
            offset = int((indeces[i] - 576) / 64)
            random_link = random.sample(range(24), 1)
            X_input_high[positions * 9 + offset, random_link] = \
                X_input_high[positions * 9 + offset, random_link] | np.uint64((1 << ((indeces[i] - 576) - offset * 64)))

    X_test_chunk = np.hstack((X_input_low, X_input_high))
    data_bitstring_padded = prep_bitstring_data(X_test_chunk)
    
    metadata = np.ones_like(X_test_chunk, dtype=np.uint8)*1
    metadata[0,:] = 13
    for i in range(113):
        if i != 0:
            metadata[i*9,:] = 5
        else:
            metadata[i*9,:] = 13
        metadata[i*9+8,:] = 3
    
    metadata[1017:1024,:] = 0
    metadata_bitstring = prep_bitstring_metadata(metadata)

    links = np.vstack((Links[0], Links[1]))
    # write out fname
    indir = "Pattern_files"
    fname = indir + "/" + file_name
    write_pattern_file(metadata_bitstring, data_bitstring_padded, outputfile=fname, links=links.flatten())

    if for_sim:
        indir = "../simulation/firmware/hdl/"
        fname = indir + "/inputPattern.mem"
        write_pattern_file(metadata_bitstring, data_bitstring_padded, outputfile=fname, links=links.flatten())

    if debug:
        for row in range(3,12):
            f = open(fname, 'r')
            print(f.readlines()[row])


def pattern_producer_prescale_test_v1(n_algo_bits, board='vu13p', debug=False):

    Possibile_indeces = range(1152)
    Possibile_rep     = range(int(1024 / 9))

    Available_links = get_Available_links(board)

    indeces = random.sample(Possibile_indeces, n_algo_bits)
    repetitions = np.random.choice(Possibile_rep, size=n_algo_bits, replace=True)
    if debug:
        print("Algo bit indeces")
        print(np.array(indeces))
        print("Algo bit repetitions")
        print(np.array(repetitions))

    X_input_low = np.zeros((1024, 24), dtype=np.uint64)
    X_input_high = np.zeros((1024, 24), dtype=np.uint64)

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


def pattern_producer_prescale_test(n_algo_bits, board='vu13p', debug=False):

    algo_matrix, indeces, repetitions = extract_random_indexes(n_algo_bits, 1152, 113, False, debug)

    Available_links = get_Available_links(board)

    pattern_data_producer_v2(algo_matrix, "Finor_input_pattern_prescaler_test.txt", Available_links, debug, for_sim=True)

    return indeces, repetitions


def pattern_producer_trggmask_test(board='vu13p', debug=False):
    Possibile_rep = range(int(113))
    N_trigg_masks = 8
    Algos_per_trigg = int(1152 / N_trigg_masks)

    algo_subset = np.random.choice(1152, [N_trigg_masks, Algos_per_trigg], replace=False)
    rep_per_trigg = np.random.choice(Possibile_rep, size=N_trigg_masks, replace=True)

    indeces = []
    positions = []
    algo_matrix = np.zeros((1152, 113), bool)

    for i in range(N_trigg_masks):
        algos_position = np.random.choice(Possibile_rep, size=rep_per_trigg[i], replace=False)
        algo_distrib = np.random.choice(algo_subset[i], size=rep_per_trigg[i], replace=True)
        indeces = np.int32(np.append(indeces, algo_distrib))
        positions = np.int32(np.append(positions, algos_position))
        for pos, local_index in zip(algos_position, algo_distrib):
            if debug:
                print(pos, local_index)
            algo_matrix[local_index, pos] = True

    if debug:
        print("Replication per trigger")
        print(rep_per_trigg)
        print("Algo indeces")
        print(indeces)

    Available_links = get_Available_links(board)

    #pattern_data_producer(indeces, positions, "Finor_input_pattern_trigg_test.txt", Available_links, debug)
    pattern_data_producer_v2(algo_matrix, "Finor_input_pattern_trigg_test.txt", Available_links, debug, False)

    return algo_subset, rep_per_trigg


def pattern_producer_veto_test(n_algo_bits, n_veto_bits, board='vu13p', debug=False):

    if n_veto_bits>n_algo_bits:
        raise Exception("n_algo_bits must be larger than n_veto_bits, \nvalues got %d and %d" % (n_algo_bits, n_veto_bits))

    algo_matrix, indeces, repetitions = extract_random_indexes(n_algo_bits, 1152, 113, True, debug)
    algo_matrix_veto = np.copy(algo_matrix)
    veto_indeces = np.random.choice(indeces, size=n_veto_bits, replace=False)
    veto_matrix = np.zeros((n_veto_bits, 113), bool)

    for i, index in enumerate(veto_indeces):
        veto_matrix[i, :] = algo_matrix[index, :]
        algo_matrix_veto[index, :] = 0

    finor = np.logical_or.reduce(algo_matrix_veto, 0).astype(bool)
    veto = np.logical_or.reduce(veto_matrix, 0).astype(bool)
    finor_with_veto = np.logical_and(finor, np.logical_not(veto)).astype(bool)

    if debug:
        print("FinalOR counts = %d" % finor.sum())
        print("FinalOR with veto counts = %d" % finor_with_veto.sum())

    finor_counts = np.vstack((finor.sum(), finor_with_veto.sum(), veto.sum()))

    Available_links = get_Available_links(board)

    pattern_data_producer_v2(algo_matrix, "Finor_input_pattern_veto_test.txt", Available_links, debug)

    return finor_counts, veto_indeces
    

def pattern_producer_BXmask_test(p_algo, p_mask, board='vu13p', debug=False):

    BX_mask = np.random.choice(a=[False, True], size=(1152, 113), p=[p_mask, 1 - p_mask])
    algo_matrix = np.random.choice(a=[False, True], size=(1152, 113), p=[p_algo, 1 - p_algo])
    algo_matrix_masked = np.logical_and(algo_matrix, BX_mask).astype(bool)

    rep_tot = np.sum(algo_matrix_masked, 1).astype(np.uint32)
    indeces = np.where(rep_tot > 0)[0]
    repetitions = rep_tot[indeces]
    finor_counts = np.sum(np.logical_or.reduce(algo_matrix_masked, 0).astype(bool)).astype(np.uint32)
    if debug:
    	print("FinalOR counts = %d" % finor_counts)

    Available_links = get_Available_links(board)

    pattern_data_producer_v2(algo_matrix, "Finor_input_pattern_BXmask_test.txt", Available_links, debug)

    return indeces, repetitions, BX_mask, finor_counts


index, repetition = pattern_producer_prescale_test(args.indexes, board, False)
indir     = "Pattern_files"
fname     = indir + "/metadata/Prescaler_test/algo_rep.txt"
algo_data = np.vstack((index,repetition))
np.savetxt(fname, algo_data, fmt='%d')

trigg_index, trigg_rep = pattern_producer_trggmask_test(board, False)
indir     = "Pattern_files"
fname     = indir + "/metadata/Trigg_mask_test/trigg_index.txt"
np.savetxt(fname, trigg_index, fmt='%d')
fname     = indir + "/metadata/Trigg_mask_test/trigg_rep.txt"
np.savetxt(fname, trigg_rep, fmt='%d')

finor_cnts, veto_indeces = pattern_producer_veto_test(50, 5, board, False)
indir     = "Pattern_files"
fname     = indir + "/metadata/Veto_test/finor_counts.txt"
np.savetxt(fname, finor_cnts, fmt='%d')
fname     = indir + "/metadata/Veto_test/veto_indeces.txt"
np.savetxt(fname, veto_indeces, fmt='%d')

index, repetition, mask, finor_cnts = pattern_producer_BXmask_test(0.999, 0.600, board, False)
indir     = "Pattern_files"
fname     = indir + "/metadata/BXmask_test/algo_rep.txt"
algo_data = np.vstack((index,repetition))
np.savetxt(fname, algo_data, fmt='%d')
indir     = "Pattern_files"
fname     = indir + "/metadata/BXmask_test/finor_counts.npy"
np.save(fname, finor_cnts)
indir     = "Pattern_files"
fname     = indir + "/metadata/BXmask_test/BX_mask.npy"
np.save(fname, mask)

