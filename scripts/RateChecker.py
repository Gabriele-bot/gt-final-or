# Script for checking pre-scale correct behaviour of the Phase-2 Finor Board.
# Developed  by Gabriele Bortolato (Padova  University)
# gabriele.bortolato@cern.ch

import os

import numpy as np
import uhal
import time
import argparse
import re
from patternfiles import *


from FinOrController import FinOrController

parser = argparse.ArgumentParser(description='GT-Final OR board Rate Checker')
parser.add_argument('-p', '--ps_column', metavar='N', type=str, default='random',
                    help='random --> random pre-scale values,\nlinear --> equally spaced pre-scale values')
parser.add_argument('-t', '--test', metavar='N', type=str, default='prescaler',
                    help='prescaler    --> start a prescaler test, '
                         '\ntrigger_mask --> start a trigger mask test '
                         '\nveto_mask    --> start a veto mask test '
                         '\nBXmask       --> start a BXmask test ')
parser.add_argument('-c', '--connections', metavar='N', type=str, default='my_connections.xml',
                    help='connections xml file')
parser.add_argument('-ls', '--lumisection', metavar='N', type=int, default=18,
                    help='Luminosity section toggle bit (within the orbit counter)')
parser.add_argument('-S', '--simulation', action='store_true',
                    help='Simulation flag')
parser.add_argument('-E', '--EMPenable', action='store_true',
                    help='EMP enable flag')
parser.add_argument('-ll', '--LowLinks', type=str, default="0-11")
parser.add_argument('-ml', '--MidLinks', type=str, default="48-59")
parser.add_argument('-hl', '--HighLinks', type=str, default="36-47")

args = parser.parse_args()

# TODO maybe put this in a config file? Or directly parse the vhdl pkg?


emp_flag = args.EMPenable
if emp_flag:
    import emp

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

uhal.disableLogging()

lumi_bit = args.lumisection


HWtest = FinOrController(connection_file=args.connections, device='x0', emp_flag=emp_flag)
slr_algos = HWtest.slr_algos
monitoring_slrs = HWtest.n_slr
# ttcNode.forceBCmd(0x24) #Send test enable command

HWtest.set_TimeOutPeriod(5000)

# Set the l1a-latency delay
l1_latency_delay = int(300)
HWtest.load_latancy_delay(l1_latency_delay)
# set link mask to enable all links in all SLRs
link_mask = np.uint32(np.ones(monitoring_slrs)*(2**24-1))
HWtest.set_link_mask(link_mask)
time.sleep(2)

# reset aligment errors
HWtest.reset_alignement_error()
if args.simulation:
    for i in range(10):
        Link_error = HWtest.check_links_error()
        time.sleep(0.1)
    time.sleep(10)
else:
    time.sleep(1)

unprescaled_low_bits_link = HWtest.get_output_ch_number(0)[0]
unprescaled_mid_bits_link = HWtest.get_output_ch_number(1)[0]
unprescaled_high_bits_link = HWtest.get_output_ch_number(2)[0]

if args.test != 'algo-out':
    HWtest.print_link_mesured_delay()

    # Print errors
    HWtest.print_link_info()

# -------------------------------------------------------------------------------------
# -----------------------------------PRE-SCALER TEST-----------------------------------
# -------------------------------------------------------------------------------------
if args.test == 'prescaler':
    # load data from PaternProducer metadata
    algo_data = np.loadtxt('Pattern_files/metadata/Prescaler_test/algo_rep.txt')
    index = algo_data[0]

    repetitions = algo_data[1]

    o_ctr = HWtest.get_orbit_ctr()
    print("Current orbit counter = %d" % np.array(o_ctr))

    # Set the bxmasks, mask everything that is not in the input window (set bt EMP FWK buffer size)
    bxmask = np.zeros((3 * int(np.ceil(slr_algos/32)), 4096), dtype=np.uint32)
    bxmask[ 0:3*int(np.ceil(slr_algos / 32)), 0:113] = np.ones_like(bxmask)[:, :113]*(2 ** 32 - 1)

    if args.simulation:
        print("Using default BXmask")
    else:
        HWtest.load_BXmask_arr(bxmask)

    # Set the trigger masks as a pass though
    trigger_mask = np.ones((8, 3, int(np.ceil(slr_algos / 32))), dtype=np.uint32) * 2 ** 32 - 1
    HWtest.load_mask_arr(trigger_mask)
    HWtest.send_new_trigger_mask_flag()

    # Set the veto mask
    veto_mask = np.zeros((3 * int(np.ceil(slr_algos / 32))), dtype=np.uint32)
    HWtest.load_veto_mask(veto_mask)
    HWtest.send_new_veto_mask_flag()

    # Set prescale factors
    prsc_fct = np.uint32(100 * np.ones((3 * slr_algos)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((3 * slr_algos)))  # 1.00
    if args.ps_column == "random":
        prsc_fct[np.int16(index)] = np.uint32(np.random.randint(100, 2 ** 24 - 101, len(index)))
    elif args.ps_column == "linear":
        prsc_fct[np.int16(index)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index)))
    HWtest.load_prsc_in_RAM(prsc_fct, 0)
    if args.ps_column == "random":
        prsc_fct_prvw[np.int16(index)] = np.uint32(np.random.randint(100, 2 ** 24 - 101, len(index)))
    elif args.ps_column == "linear":
        prsc_fct_prvw[np.int16(index)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index)))
    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)
    HWtest.send_new_prescale_column_flag(0)
    HWtest.send_new_prescale_column_flag(1)

    time.sleep(2)

    HWtest.print_lumisection_mark()

    # compute expected rate
    rate_before_theo = np.float64(np.zeros(slr_algos*3))
    rate_after_theo = np.float64(np.zeros(slr_algos*3))
    rate_prvw_theo = np.float64(np.zeros(slr_algos*3))

    rate_before_theo[np.uint32(index)] = np.uint32(repetitions * (2 ** lumi_bit))
    rate_after_theo[np.uint32(index)] = np.uint32(
        repetitions * (2 ** lumi_bit) / prsc_fct[np.int16(index)] * 100)
    rate_prvw_theo[np.uint32(index)] = np.uint32(
        repetitions * (2 ** lumi_bit) / prsc_fct_prvw[np.int16(index)] * 100)

    o_ctr_0 = HWtest.get_orbit_ctr()
    o_ctr = o_ctr_0
    while (o_ctr - o_ctr_0) < 2 ** (lumi_bit + 1):
        time.sleep(0.05)
        o_ctr = HWtest.get_orbit_ctr()

    o_ctr_temp = 0

    error_cnt = 0

    if args.simulation:
        iteration = 2
    else:
        iteration = 5

    for i in range(iteration):
        while ((o_ctr >> lumi_bit) == (o_ctr_temp >> lumi_bit)):
            time.sleep(0.05)
            o_ctr = HWtest.get_orbit_ctr()
        o_ctr_temp = o_ctr

        ready = HWtest.check_counter_ready_flags()
        while not (np.logical_or.reduce(ready, 0).astype(bool)):
            print("Counters are not ready to be read")
            time.sleep(5)
            ready = HWtest.check_counter_ready_flags()

        cnt_before = HWtest.read_cnt_arr(0)
        cnt_after = HWtest.read_cnt_arr(1)
        cnt_prvw = HWtest.read_cnt_arr(2)
        # cnt_pdt = HWtest.read_cnt_arr(3)

        print("Current orbit counter = %d" % o_ctr)

        o_ctr_temp = o_ctr

        rate_before_exp = cnt_before
        rate_after_exp = cnt_after
        rate_prvw_exp = cnt_prvw

        error_before = np.abs(rate_before_exp - rate_before_theo)
        error_after = np.abs(rate_after_exp - rate_after_theo)
        error_preview = np.abs(rate_prvw_exp - rate_prvw_theo)

        for current_i, error in enumerate(error_before):
            if error > 1:
                error_cnt += 1
                print('Mismatch found on rate BEFORE pescaler %d, error= %d' % (current_i, error))
                print('Expected value = %d, Value got= %d' % (
                    rate_before_theo[current_i], rate_before_exp[current_i]))
        for current_i, error in enumerate(error_after):
            if error > 1:
                error_cnt += 1
                print('Mismatch found on rate AFTER pescaler %d, error= %d' % (current_i, error))
                print('Expected value %d, Value got= %d' % (rate_after_theo[current_i], rate_after_exp[current_i]))
                print('Pre-scale value set = %d' % prsc_fct.flatten()[current_i])
        for current_i, error in enumerate(error_preview):
            if error > 1:
                error_cnt += 1
                print('Mismatch found on rate AFTER pescaler PREVIEW %d, error= %d' % (current_i, error))
                print('Expected value %d, Value got= %d' % (rate_prvw_theo[current_i], rate_prvw_exp[current_i]))
                print('Pre-scale value set = %d' % prsc_fct_prvw.flatten()[current_i])


    if error_cnt:
        raise Exception("Error found! Check the counters!")
    else:
        print("No mismatch found!")

# -------------------------------------------------------------------------------------
# -----------------------------------TRIGG MASK TEST-----------------------------------
# -------------------------------------------------------------------------------------
elif args.test == 'trigger_mask':

    # load data from PaternProducer metadata
    trigg_index = np.loadtxt('Pattern_files/metadata/Trigg_mask_test/trigg_index.txt')
    trigg_rep = np.loadtxt('Pattern_files/metadata/Trigg_mask_test/trigg_rep.txt')

    bxmask = np.zeros((3 * int(np.ceil(slr_algos / 32)), 4096), dtype=np.uint32)
    bxmask[0:3 * int(np.ceil(slr_algos / 32)), 0:113] = np.ones_like(bxmask)[:, :113] * (2 ** 32 - 1)

    if args.simulation:
        print("Using default BXmask")
    else:
        HWtest.load_BXmask_arr(bxmask)

    # Set the masks to match trigg_index
    trigger_mask = HWtest.convert_index2mask(trigg_index, 8)
    HWtest.load_mask_arr(trigger_mask)
    HWtest.send_new_trigger_mask_flag()

    veto_mask = np.zeros((3 * int(np.ceil(slr_algos / 32))), dtype=np.uint32)
    HWtest.load_veto_mask(veto_mask)
    HWtest.send_new_veto_mask_flag()

    # Set pre-scaler factors
    prsc_fct = np.uint32(100 * np.ones((3 * slr_algos)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((3 * slr_algos)))  # 1.00
    HWtest.load_prsc_in_RAM(prsc_fct, 0)
    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)
    HWtest.send_new_prescale_column_flag(0)
    HWtest.send_new_prescale_column_flag(1)

    time.sleep(2)

    HWtest.print_lumisection_mark()

    # compute expected rate
    trigg_rate_theo = np.float64(np.zeros(8))
    for i in range(8):
        trigg_rate_theo[i] = np.uint32(trigg_rep[i] * (2 ** lumi_bit))

        # Wait for 2 lumi section, 1 to load the masks and 1 to let the counters actually count
    o_ctr_0 = HWtest.get_orbit_ctr()
    o_ctr = o_ctr_0
    while (o_ctr - o_ctr_0) < 2 ** (lumi_bit + 1):
        time.sleep(0.05)
        o_ctr = HWtest.get_orbit_ctr()

    o_ctr_temp = 0

    error_cnt = 0

    if args.simulation:
        iteration = 2
    else:
        iteration = 5

    format_row = "{:>20}" * 9

    for i in range(iteration):
        print(format_row.format('Rate Counter', 'Trigger 0', 'Trigger 1', 'Trigger 2', 'Trigger 3', 'Trigger 4',
                                'Trigger 5', 'Trigger 6', 'Trigger 7'))
        while ((o_ctr >> lumi_bit) == (o_ctr_temp >> lumi_bit)):
            time.sleep(0.05)
            o_ctr = HWtest.get_orbit_ctr()
        o_ctr_temp = o_ctr

        ready = HWtest.check_trigger_counter_ready_flag()
        while not ready:
            time.sleep(5)
            ready = HWtest.check_trigger_counter_ready_flag()

        trigg_cnt = HWtest.read_trigg_cnt(0)
        trigg_cnt_pdt = HWtest.read_trigg_cnt(1)
        trigg_cnt_wveto = HWtest.read_trigg_cnt(4)
        trigg_cnt_pdt_wveto = HWtest.read_trigg_cnt(5)

        print(format_row.format('Trigger', *trigg_cnt))
        print(format_row.format('Trigger pdt', *trigg_cnt_pdt))
        print(format_row.format('Trigger vetoed', *trigg_cnt_wveto))
        print(format_row.format('Trigger pdt vetoed', *trigg_cnt_pdt_wveto))

        for trigg_index, cnt in enumerate(trigg_cnt):
            error_trgg = np.abs(trigg_rate_theo[trigg_index] - cnt)
            if error_trgg > 0:
                error_cnt += 1
                print('Mismatch found on %d-th trigger rate, error= %d' % (trigg_index, error_trgg))
                print('Expected value %d, Value got= %d' % (trigg_rate_theo[trigg_index], trigg_cnt[trigg_index]))

    # sys.stdout.flush()

    if error_cnt:
        raise Exception("Error found! Check the counters!")
    else:
        print("No mismatch found!")

# -------------------------------------------------------------------------------------
# -----------------------------------VETO TEST-----------------------------------------
# -------------------------------------------------------------------------------------
elif args.test == 'veto_mask':

    # load data from PaternProducer metadata
    cnts = np.loadtxt('Pattern_files/metadata/Veto_test/finor_counts.txt')
    finor_cnts = cnts[0]
    finor_with_veto_cnts = cnts[1]
    veto_cnts = cnts[2]

    veto_indeces = np.loadtxt('Pattern_files/metadata/Veto_test/veto_indeces.txt')

    bxmask = np.zeros((3 * int(np.ceil(slr_algos / 32)), 4096), dtype=np.uint32)
    bxmask[:3 * int(np.ceil(slr_algos / 32)), 0:113] = np.ones_like(bxmask)[:, :113] * (2 ** 32 - 1)

    if args.simulation:
        print("Using default BXmask")
    else:
        HWtest.load_BXmask_arr(bxmask)

    # Set the trigger masks as a pass though
    trigger_mask = np.ones((8, 3, int(np.ceil(slr_algos / 32))), dtype=np.uint32) * 2 ** 32 - 1
    HWtest.load_mask_arr(trigger_mask)
    HWtest.send_new_trigger_mask_flag()

    # Set the veto mask
    veto_mask = HWtest.convert_index2mask(veto_indeces, 1)
    HWtest.load_veto_mask(veto_mask)
    HWtest.send_new_veto_mask_flag()

    # Set pre-scaler factors
    prsc_fct = np.uint32(100 * np.ones((3 * slr_algos)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((3 * slr_algos)))  # 1.00
    HWtest.load_prsc_in_RAM(prsc_fct, 0)
    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)
    HWtest.send_new_prescale_column_flag(0)
    HWtest.send_new_prescale_column_flag(1)

    time.sleep(2)

    HWtest.print_lumisection_mark()

    # compute expected rate
    trigg_rate_theo = np.float64(np.zeros(8))
    trigg_rate_with_veto_theo = np.float64(np.zeros(8))
    for i in range(8):
        trigg_rate_theo[i] = np.uint32(finor_cnts * (2 ** lumi_bit))
        trigg_rate_with_veto_theo[i] = np.uint32(finor_with_veto_cnts * (2 ** lumi_bit))
    veto_theo = veto_cnts * (2 ** lumi_bit)

    # Wait for 2 lumi section, 1 to load the masks and 1 to let the counters actually count
    o_ctr_0 = HWtest.get_orbit_ctr()
    o_ctr = o_ctr_0
    HWtest.hw.dispatch()
    while (o_ctr - o_ctr_0) < 2 ** (lumi_bit + 1):
        time.sleep(0.05)
        o_ctr = HWtest.get_orbit_ctr()

    o_ctr_temp = 0

    error_cnt = 0

    if args.simulation:
        iteration = 2
    else:
        iteration = 5

    format_row = "{:>20}" * 9

    for i in range(iteration):
        print(format_row.format('Rate Counter', 'Trigger 0', 'Trigger 1', 'Trigger 2', 'Trigger 3', 'Trigger 4',
                                'Trigger 5', 'Trigger 6', 'Trigger 7'))
        while ((o_ctr >> lumi_bit) == (o_ctr_temp >> lumi_bit)):
            time.sleep(0.05)
            o_ctr = HWtest.get_orbit_ctr()
        o_ctr_temp = o_ctr

        ready = HWtest.check_trigger_counter_ready_flag()
        while not ready:
            time.sleep(5)
            ready = HWtest.check_trigger_counter_ready_flag()

        trigg_cnt = HWtest.read_trigg_cnt(0)
        trigg_cnt_pdt = HWtest.read_trigg_cnt(1)
        trigg_cnt_wveto = HWtest.read_trigg_cnt(4)
        trigg_cnt_pdt_wveto = HWtest.read_trigg_cnt(5)

        veto_cnt_reg = HWtest.read_veto_cnt()
        veto_cnt_SLRs_reg = np.zeros(3)
        for i in range(HWtest.n_slr):
            veto_cnt_SLRs_reg[i] = HWtest.read_partial_veto_cnt(i)

        print(format_row.format('Trigger', *trigg_cnt))
        print(format_row.format('Trigger pdt', *trigg_cnt_pdt))
        print(format_row.format('Trigger vetoed', *trigg_cnt_wveto))
        print(format_row.format('Trigger pdt vetoed', *trigg_cnt_pdt_wveto))

        print('Veto counter value = %d' % (veto_cnt_reg))
        for i in range(HWtest.n_slr):
            print('Veto counter SLR n%d value = %d' % (i, veto_cnt_SLRs_reg[i]))


        for trigg_index, cnt in enumerate(trigg_cnt):
            error_trgg = np.abs(trigg_rate_theo[trigg_index] - cnt)
            if error_trgg > 0:
                error_cnt += 1
                print('Mismatch found on %d-th trigger rate, error= %d' % (trigg_index, error_trgg))
                print('Expected value %d, Value got= %d' % (trigg_rate_theo[trigg_index], trigg_cnt[trigg_index]))

        for trigg_index, cnt in enumerate(trigg_cnt_wveto):
            error_trgg = np.abs(trigg_rate_with_veto_theo[trigg_index] - cnt)
            if error_trgg > 0:
                error_cnt += 1
                print('Mismatch found on %d-th trigger rate with veto, error= %d' % (trigg_index, error_trgg))
                print('Expected value %d, Value got= %d' % (trigg_rate_with_veto_theo[trigg_index], cnt))

        error_veto = np.abs(veto_theo - veto_cnt_reg)
        if error_veto > 0:
            error_cnt += 1
            print('Mismatch found on veto counter, error= %d' % error_veto)
            print('Expected value %d, Value got= %d' % (veto_theo, veto_cnt_reg))

    # sys.stdout.flush()

    if error_cnt:
        raise Exception("Error found! Check the counters!")
    else:
        print("No mismatch found!")

# -------------------------------------------------------------------------------------
# -----------------------------------BX MASK TEST--------------------------------------
# -------------------------------------------------------------------------------------
elif args.test == 'BXmask':

    # load data from PaternProducer metadata
    algo_data = np.loadtxt('Pattern_files/metadata/BXmask_test/algo_rep.txt')
    indeces = algo_data[0]
    repetitions = algo_data[1]

    BX_mask = np.load('Pattern_files/metadata/BXmask_test/BX_mask.npy')
    bxmask = np.zeros((3 * int(np.ceil(slr_algos / 32)), 4096), dtype=np.uint32)
    # set the BX mask accordingly
    for BX_nr in range(np.shape(BX_mask)[1]):
        for index, mask in enumerate(BX_mask[:, BX_nr]):
            reg_index = np.uint16(np.floor(index / 32))
            bit_pos = np.uint16(index - reg_index * 32)
            bxmask[reg_index, BX_nr] = (bxmask[reg_index, BX_nr]) | (np.uint32(mask) << bit_pos)
    HWtest.load_BXmask_arr(bxmask)

    # Set the trigger masks as a pass though
    trigger_mask = np.ones((8, 3, int(np.ceil(slr_algos / 32))), dtype=np.uint32) * 2 ** 32 - 1
    HWtest.load_mask_arr(trigger_mask)
    HWtest.send_new_trigger_mask_flag()

    # Set the veto mask
    veto_mask = np.zeros((3, int(np.ceil(slr_algos / 32))), dtype=np.uint32)
    HWtest.load_veto_mask(veto_mask)
    HWtest.send_new_veto_mask_flag()

    # Set pre-scaler factors
    prsc_fct = np.uint32(100 * np.ones((3, slr_algos)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((3, slr_algos)))  # 1.00
    HWtest.load_prsc_in_RAM(prsc_fct, 0)
    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)
    HWtest.send_new_prescale_column_flag(0)
    HWtest.send_new_prescale_column_flag(1)

    time.sleep(2)

    HWtest.print_lumisection_mark()
    
    # compute expected rate
    rate_before_theo = np.float64(np.zeros(slr_algos*3))

    rate_before_theo[np.uint32(indeces)] = np.uint32(repetitions * (2 ** lumi_bit))

    # Wait for 2 lumi section, 1 to load the masks and 1 to let the counters actually count
    o_ctr_0 = HWtest.get_orbit_ctr()
    o_ctr = o_ctr_0
    while (o_ctr - o_ctr_0) < 2 ** (lumi_bit + 1):
        time.sleep(0.05)
        o_ctr = HWtest.get_orbit_ctr()

    o_ctr_temp = 0

    error_cnt = 0

    if args.simulation:
        iteration = 2
    else:
        iteration = 5

    for i in range(iteration):
        while ((o_ctr >> lumi_bit) == (o_ctr_temp >> lumi_bit)):
            time.sleep(0.05)
            o_ctr = HWtest.get_orbit_ctr()
        o_ctr_temp = o_ctr

        ready = HWtest.check_counter_ready_flags()
        while not (np.logical_or.reduce(ready, 0).astype(bool)):
            print("Counters are not ready to be read")
            time.sleep(5)
            ready = HWtest.check_counter_ready_flags()

        # ttcStatus = ttcNode.readStatus()
        print("Current orbit counter = %d" % o_ctr)

        cnt_before = HWtest.read_cnt_arr(0)

        rate_before_exp = cnt_before

        error_before = np.abs(rate_before_exp - rate_before_theo)

        for current_i, error in enumerate(error_before):
            if error > 0:
                error_cnt += 1
                print('Mismatch found on rate before pescaler %d, error= %d' % (current_i, error))
                print('Expected value %d, Value got= %d' % (rate_before_theo[current_i], rate_before_exp[current_i]))
    # sys.stdout.flush()

    if error_cnt != 0:
        raise Exception("Error found! Check the counters!")
    else:
        print("No mismatch found!")

# -------------------------------------------------------------------------------------
# ----------------------------ALGO OUT TEST--------------------------------------------
# -------------------------------------------------------------------------------------
elif args.test == 'algo-out':

    in_valid, in_data, _ = read_pattern_file('Pattern_files/Finor_input_pattern_prescaler_test.txt', True)
    try:
        out_valid, out_data, links = read_pattern_file('out_prescaler_test.txt', True)
    except:
        raise ("Did you run the prescale test beforehand?")

    input_links = np.vstack((parse_index_list_string(args.LowLinks), parse_index_list_string(args.MidLinks), parse_index_list_string(args.HighLinks)))

    temp_or = np.zeros(np.shape(in_data)[1], dtype=np.uint64)
    # put to 0 invalid frames
    temp_data_in = in_valid[:len(input_links[0])] * in_data[:len(input_links[0])]

    for i in range(np.shape(input_links)[1]):
        temp_or = np.bitwise_or(temp_or, temp_data_in[i, :])

    # extract deserialized valid data
    output_link_data = []
    for i in range(np.shape(out_data)[1]):
        if out_valid[np.where(links == unprescaled_low_bits_link), i] == 1:
            output_link_data = np.append(output_link_data, out_data[np.where(links == unprescaled_low_bits_link), i])

    # print(output_link_data)

    if np.array_equal(output_link_data, temp_or[:len(output_link_data)]):
        print("Lower output algobit pattern match the input data ORing (unprescaled)")
    else:
        raise Exception('Mismatch was found, check your pattern files and/or the registers')

    temp_or = np.zeros(np.shape(in_data)[1], dtype=np.uint64)
    temp_data_in = in_valid[len(input_links[0]):(len(input_links[0]) + len(input_links[1]))] * \
                   in_data[len(input_links[0]):(len(input_links[0]) + len(input_links[1]))]

    for i in range(np.shape(input_links)[1]):
        temp_or = np.bitwise_or(temp_or, temp_data_in[i, :])

    output_link_data = []
    for i in range(np.shape(out_data)[1]):
        if out_valid[np.where(links == unprescaled_mid_bits_link), i] == 1:
            output_link_data = np.append(output_link_data, out_data[np.where(links == unprescaled_mid_bits_link), i])

    if np.array_equal(output_link_data, temp_or[:len(output_link_data)]):
        print("Mid output algobit pattern match the input data ORing (unprescaled)")
    else:
        raise Exception('Mismatch was found, check your pattern files and/or the registers')

    temp_or = np.zeros(np.shape(in_data)[1], dtype=np.uint64)
    temp_data_in = in_valid[len(input_links[0]) + len(input_links[1]):(len(input_links[0]) + len(input_links[1]) + len(input_links[2]))] * \
                   in_data[len(input_links[0]) + len(input_links[1]):(len(input_links[0]) + len(input_links[1]) + len(input_links[2]))]

    for i in range(np.shape(input_links)[1]):
        temp_or = np.bitwise_or(temp_or, temp_data_in[i, :])

    output_link_data = []
    for i in range(np.shape(out_data)[1]):
        if out_valid[np.where(links == unprescaled_mid_bits_link), i] == 1:
            output_link_data = np.append(output_link_data, out_data[np.where(links == unprescaled_high_bits_link), i])

    if np.array_equal(output_link_data, temp_or[:len(output_link_data)]):
        print("High output algobit pattern match the input data ORing (unprescaled)")
    else:
        raise Exception('Mismatch was found, check your pattern files and/or the registers')


else:
    print('No suitable test was selected!')
