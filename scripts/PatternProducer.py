# Script for generating input pattern file for the Phase-2 Finor Board.
# Developed  by Gabriele Bortolato (Padova  University)
# gabriele.bortolato@cern.ch

import numpy as np
import random
import argparse
import re

from patternfiles import *
from bitstringconverter import *

parser = argparse.ArgumentParser(description='GT-Final OR board Pattern producer')
parser.add_argument('-i', '--indexes', metavar='N', type=int, default=1,
                    help='Number of algos to send')
parser.add_argument('-a', '--slr_algos', metavar='N', type=int, default=576,
                    help='Number of algos per SLR')
parser.add_argument('-m', '--Monitoring_slr', metavar='N', type=int, default=2,
                    help='Number of algos per SLR')
parser.add_argument('-T', '--TMUX2',action='store_true',
                    help='Enable TMUX2 pattern file')
parser.add_argument('-ll', '--LowLinks', type=str, default="0-11")
parser.add_argument('-ml', '--MidLinks', type=str, default="36-47")
parser.add_argument('-hl', '--HighLinks', type=str, default="48-59")

args = parser.parse_args()

board = 'vu13p'
max_BXs = 112

#################################### Channel Parser #######################################

# from https://gitlab.cern.ch/cms-cactus/phase2/pyswatch/-/blob/master/src/swatch/config.py

_INDEX_LIST_STRING_REGEX = re.compile(r'([0-9]+(?:-[0-9]+)?)(?:,([0-9]+(?:-[0-9]+)?))*')


def parse_index_list_string(index_list_str):
    if not re.match(_INDEX_LIST_STRING_REGEX, index_list_str):
        raise RuntimeError(f'Index list string "{index_list_str}" has incorrect format')
    tokens = index_list_str.split(',')
    indices = []
    for token in tokens:
        if '-' in token:
            start, end = token.split('-')
            start = int(start)
            end = int(end)
            step = (end - start) // abs(end - start)
            for i in range(start, end + step, step):
                indices.append(i)
        else:
            indices.append(int(token))

    return indices


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


def get_algo_indeces(N_slr_algos, N_monitoring_slr):
    if N_monitoring_slr == 1:
        Possibile_indeces = list(range(N_slr_algos))
    elif N_monitoring_slr == 2:
        Possibile_indeces = list(np.hstack((range(N_slr_algos), range(576, 576 + N_slr_algos, 1))))
    elif N_monitoring_slr == 3:
        Possibile_indeces = list(np.hstack((range(N_slr_algos), range(576, 576 + N_slr_algos, 1), range(1152, 1152 + N_slr_algos, 1))))
    else:
        Possibile_indeces = list(np.hstack((range(N_slr_algos), range(576, 576 + N_slr_algos, 1))))

    return Possibile_indeces
def extract_random_indexes(n_algo_bits, N_slr_algos, N_monitoring_slr, max_rep=max_BXs, low_rep=True, debug=False):
    Possibile_indeces = get_algo_indeces(N_slr_algos, N_monitoring_slr)
    Possibile_rep = range(int(max_rep))

    indeces = random.sample(Possibile_indeces, n_algo_bits)
    end_point = 25
    p = np.exp(-np.arange(0, end_point, end_point / (max_BXs - 1)))
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

    algo_matrix = np.zeros((N_monitoring_slr*576, max_rep), bool)

    for rep, index in zip(repetitions, indeces):
        random_spot = np.random.choice(Possibile_rep, size=rep, replace=False)
        for i in random_spot:
            algo_matrix[index, i] = True

    return algo_matrix, indeces, repetitions


def get_Available_links(arguments):
    Available_links = np.vstack(
            (parse_index_list_string(arguments.LowLinks), parse_index_list_string(arguments.MidLinks),
             parse_index_list_string(arguments.HighLinks)))

    return Available_links


def merge_indeces(indeces, N_slr_algos):
    new_indeces = np.copy(indeces)
    errors = 0
    for n, i in enumerate(new_indeces):
        if 576 <= i < 1152:
            new_indeces[n] = i - (576 - N_slr_algos)
        elif 1152 <= i < 1728:
            new_indeces[n] = i - (1152 - N_slr_algos*2)
        if (N_slr_algos <= i < 576) | (576 + N_slr_algos <= i < 1152) | (1152 + N_slr_algos <= i < 1728):
            errors = errors + 1

    if errors > 0:
        print("ahia")

    return new_indeces


def pattern_data_producer(indeces, positions, file_name, Links, debug):
    print(Links.shape[0])
    X_input_low = np.zeros((max_BXs*9, len(Links[0])), dtype=np.uint64)
    X_input_mid = np.zeros((max_BXs*9, len(Links[1])), dtype=np.uint64)
    X_input_high = np.zeros((max_BXs*9, len(Links[2])), dtype=np.uint64)

    for i in range(len(indeces)):
        if indeces[i] < 576:
            offset = int(indeces[i] / 64)
            random_link = random.sample(range(len(Links[0])), 1)
            X_input_low[positions[i] * 9 + offset, random_link] = \
                X_input_low[positions[i] * 9 + offset, random_link] | np.uint64((1 << (indeces[i] - offset * 64)))
        elif 576 <= indeces[i] < 1152:
            offset = int((indeces[i] - 576) / 64)
            random_link = random.sample(range(len(Links[1])), 1)
            X_input_mid[positions[i] * 9 + offset, random_link] = \
                X_input_mid[positions[i] * 9 + offset, random_link] | np.uint64(
                    (1 << ((indeces[i] - 576) - offset * 64)))
        else:
            offset = int((indeces[i] - 1152) / 64)
            random_link = random.sample(range(len(Links[2])), 1)
            X_input_high[positions[i] * 9 + offset, random_link] = \
                X_input_high[positions[i] * 9 + offset, random_link] | np.uint64(
                    (1 << ((indeces[i] - 1152) - offset * 64)))

    X_test_chunk = np.hstack((X_input_low, X_input_mid, X_input_high))
    data_bitstring_padded = prep_bitstring_data(X_test_chunk)

    links = np.vstack((Links[0], Links[1], Links[2]))
    # write out fname
    indir = "Pattern_files"
    fname = indir + "/" + file_name
    write_pattern_file(data_bitstring_padded, outputfile=fname, links=links.flatten())

    if debug:
        for row in range(3, 12):
            f = open(fname, 'r')
            print(f.readlines()[row])


def pattern_data_producer_v2(algo_matrix, file_name, Links, debug, TMUX2=False):
    X_input_low = np.zeros((max_BXs*9, len(Links[0])), dtype=np.uint64)
    X_input_mid = np.zeros((max_BXs*9, len(Links[1])), dtype=np.uint64)
    X_input_high = np.zeros((max_BXs*9, len(Links[2])), dtype=np.uint64)

    Possibile_rep = np.array(range(max_BXs))
    Possibile_indeces = np.array(get_algo_indeces(576, args.Monitoring_slr))
    index_mask = np.logical_or.reduce(algo_matrix, 1).astype(bool)
    indeces = Possibile_indeces[index_mask]

    for i in range(len(indeces)):
        postition_mask = algo_matrix[indeces[i], :]
        positions = Possibile_rep[postition_mask]
        if indeces[i] < 576:
            offset = int(indeces[i] / 64)
            random_link = random.sample(range(len(Links[0])), 1)
            X_input_low[positions * 9 + offset, random_link] = \
                X_input_low[positions * 9 + offset, random_link] | np.uint64((1 << (indeces[i] - offset * 64)))
        elif 576 <= indeces[i] < 1152:
            offset = int((indeces[i] - 576) / 64)
            random_link = random.sample(range(len(Links[1])), 1)
            X_input_mid[positions * 9 + offset, random_link] = \
                X_input_mid[positions * 9 + offset, random_link] | np.uint64((1 << ((indeces[i] - 576) - offset * 64)))
        else:
            offset = int((indeces[i] - 1152) / 64)
            random_link = random.sample(range(len(Links[2])), 1)
            X_input_high[positions * 9 + offset, random_link] = \
                X_input_high[positions * 9 + offset, random_link] | np.uint64((1 << ((indeces[i] - 1152) - offset * 64)))

    X_test_chunk = np.hstack((X_input_low, X_input_mid, X_input_high))
    data_bitstring_padded = prep_bitstring_data(X_test_chunk)

    metadata = np.ones_like(X_test_chunk, dtype=np.uint8) * 1
    metadata[0, :] = 13     # start of orbit, start and valid
    if TMUX2:
        for i in range(int(max_BXs/2)):
            if i != 0:
                metadata[i * 18, :] = 5
            else:
                metadata[i, :] = 13
            metadata[i * 18 + 17, :] = 3
    else:
        for i in range(max_BXs):
            if i != 0:
                metadata[i * 9, :] = 5
        else:
            metadata[i, :] = 13
        metadata[i * 9 + 8, :] = 3

    metadata[max_BXs*9:1024, :] = 0
    metadata_bitstring = prep_bitstring_metadata(metadata)

    links = np.vstack((Links[0], Links[1], Links[2]))
    # write out fname
    indir = "Pattern_files"
    fname = indir + "/" + file_name
    write_pattern_file(metadata_bitstring, data_bitstring_padded, outputfile=fname, links=links.flatten())

    if debug:
        for row in range(3, 12):
            f = open(fname, 'r')
            print(f.readlines()[row])


def pattern_producer_prescale_test(n_algo_bits, N_slr_algos=args.slr_algos, N_Monitoring_slr=args.Monitoring_slr, debug=False):
    algo_matrix, indeces, repetitions = extract_random_indexes(n_algo_bits, N_slr_algos, N_Monitoring_slr, max_BXs, False, debug)
    Available_links = get_Available_links(args)

    pattern_data_producer_v2(algo_matrix, "Finor_input_pattern_prescaler_test.txt", Available_links, debug,
                             TMUX2=True)

    new_indeces = merge_indeces(indeces, args.slr_algos)

    return new_indeces, repetitions


def pattern_producer_trggmask_test(debug=False):
    Possible_rep = range(int(max_BXs))
    N_trigg_masks = 8
    Algos_per_trigg = int(args.slr_algos*args.Monitoring_slr / N_trigg_masks)
    Possible_indeces = get_algo_indeces(args.slr_algos, args.Monitoring_slr)

    algo_subset = np.random.choice(Possible_indeces, [N_trigg_masks, Algos_per_trigg], replace=False)
    rep_per_trigg = np.random.choice(Possible_rep, size=N_trigg_masks, replace=True)

    indeces = []
    positions = []
    algo_matrix = np.zeros((576*args.Monitoring_slr, max_BXs), bool)

    for i in range(N_trigg_masks):
        algos_position = np.random.choice(Possible_rep, size=rep_per_trigg[i], replace=False)
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

    Available_links = get_Available_links(args)

    # pattern_data_producer(indeces, positions, "Finor_input_pattern_trigg_test.txt", Available_links, debug)
    pattern_data_producer_v2(algo_matrix, "Finor_input_pattern_trigg_test.txt", Available_links, debug, True)

    new_algo_subset = np.copy(algo_subset)

    for n, algo_set in enumerate(algo_subset):
        new_algo_subset[n] = merge_indeces(algo_set, args.slr_algos)

    return new_algo_subset, rep_per_trigg


def pattern_producer_veto_test(n_algo_bits, n_veto_bits, debug=False):
    if n_veto_bits > n_algo_bits:
        raise Exception(
            "n_algo_bits must be larger than n_veto_bits, \nvalues got %d and %d" % (n_algo_bits, n_veto_bits))

    algo_matrix, indeces, repetitions = extract_random_indexes(n_algo_bits, args.slr_algos, args.Monitoring_slr, max_BXs, True, debug)
    algo_matrix_veto = np.copy(algo_matrix)
    veto_indeces = np.random.choice(indeces, size=n_veto_bits, replace=False)
    veto_matrix = np.zeros((n_veto_bits, max_BXs), bool)

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

    Available_links = get_Available_links(args)

    pattern_data_producer_v2(algo_matrix, "Finor_input_pattern_veto_test.txt", Available_links, debug, True)

    new_veto_indeces = merge_indeces(veto_indeces, args.slr_algos)

    return finor_counts, new_veto_indeces


def pattern_producer_BXmask_test(p_algo, p_mask, N_slr_algos=args.slr_algos, N_Monitoring_slr=args.Monitoring_slr, debug=False):
    BX_mask = np.random.choice(a=[False, True], size=(576*N_Monitoring_slr, max_BXs), p=[p_mask, 1 - p_mask])
    algo_matrix = np.random.choice(a=[False, True], size=(576*N_Monitoring_slr, max_BXs), p=[p_algo, 1 - p_algo])
    algo_matrix[N_slr_algos:576] = False
    BX_mask[N_slr_algos:576] = False
    if N_Monitoring_slr >= 2:
        algo_matrix[576 + N_slr_algos:1152] = False
        BX_mask[576 + N_slr_algos:1152] = False
    if N_Monitoring_slr >= 3:
        algo_matrix[1152 + N_slr_algos:1728] = False
        BX_mask[1152 + N_slr_algos:1728] = False





    BX_mask_new = np.zeros(shape=(N_slr_algos * N_Monitoring_slr, max_BXs))
    BX_mask_new[:N_slr_algos, :max_BXs] = BX_mask[:N_slr_algos, :max_BXs]
    if N_Monitoring_slr >= 2:
        BX_mask_new[N_slr_algos:N_slr_algos * 2, :max_BXs] = BX_mask[576:576 + N_slr_algos, :max_BXs]
    if N_Monitoring_slr >= 3:
        BX_mask_new[N_slr_algos * 2:N_slr_algos * 3, :max_BXs] = BX_mask[1152:1152 + N_slr_algos, :max_BXs]

    algo_matrix_masked = np.logical_and(algo_matrix, BX_mask).astype(bool)

    rep_tot = np.sum(algo_matrix_masked, 1).astype(np.uint32)
    indeces = np.where(rep_tot > 0)[0]
    repetitions = rep_tot[indeces]
    finor_counts = np.sum(np.logical_or.reduce(algo_matrix_masked, 0).astype(bool)).astype(np.uint32)
    if debug:
        print("FinalOR counts = %d" % finor_counts)

    Available_links = get_Available_links(args)

    pattern_data_producer_v2(algo_matrix, "Finor_input_pattern_BXmask_test.txt", Available_links, debug, True)

    new_indeces = merge_indeces(indeces, args.slr_algos)

    return new_indeces, repetitions, BX_mask_new, finor_counts


index, repetition = pattern_producer_prescale_test(args.indexes, args.slr_algos, args.Monitoring_slr, False)
indir = "Pattern_files"
fname = indir + "/metadata/Prescaler_test/algo_rep.txt"
algo_data = np.vstack((index, repetition))
np.savetxt(fname, algo_data, fmt='%d')

trigg_index, trigg_rep = pattern_producer_trggmask_test(False)
indir = "Pattern_files"
fname = indir + "/metadata/Trigg_mask_test/trigg_index.txt"
np.savetxt(fname, trigg_index, fmt='%d')
fname = indir + "/metadata/Trigg_mask_test/trigg_rep.txt"
np.savetxt(fname, trigg_rep, fmt='%d')

finor_cnts, veto_indeces = pattern_producer_veto_test(50, 5, False)
indir = "Pattern_files"
fname = indir + "/metadata/Veto_test/finor_counts.txt"
np.savetxt(fname, finor_cnts, fmt='%d')
fname = indir + "/metadata/Veto_test/veto_indeces.txt"
np.savetxt(fname, veto_indeces, fmt='%d')

index, repetition, mask, finor_cnts = pattern_producer_BXmask_test(0.5, 0.999, args.slr_algos, args.Monitoring_slr, False)
indir = "Pattern_files"
fname = indir + "/metadata/BXmask_test/algo_rep.txt"
algo_data = np.vstack((index, repetition))
np.savetxt(fname, algo_data, fmt='%d')
indir = "Pattern_files"
fname = indir + "/metadata/BXmask_test/finor_counts.npy"
np.save(fname, finor_cnts)
indir = "Pattern_files"
fname = indir + "/metadata/BXmask_test/BX_mask.npy"
np.save(fname, mask)
