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
parser.add_argument('-c', '--connections', metavar='N', type=str, default='my_connection.xml',
                    help='connections xml file')
parser.add_argument('-ls', '--lumisection', metavar='N', type=int, default=18,
                    help='Luminosity section toggle bit (within the orbit counter)')
parser.add_argument('-S', '--simulation', action='store_true',
                    help='Simulation flag')
parser.add_argument('-ll', '--LowLinks', type=str, default="0-11")
parser.add_argument('-ml', '--MidLinks', type=str, default="48-59")
parser.add_argument('-hl', '--HighLinks', type=str, default="36-47")

args = parser.parse_args()

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

if args.test != 'algo-out':
    HWtest = FinOrController(serenity='Serenity3', connection_file=args.connections, device='x0', emp_flag=False)

    # EMPdevice = HWtest.get_device()
    # ttcNode   = EMPdevice.getTTC()
    # ttcNode.forceBCmd(0x24) #Send test enable command

    HWtest.set_TimeOutPeriod(5000)

    # Set the l1a-latency delay
    l1_latency_delay = int(300)
    HWtest.load_latancy_delay(l1_latency_delay)
    HWtest.set_link_mask(0x00ffffff, 0x00ffffff, 0x00ffffff)
    time.sleep(2)

    delay = HWtest.read_ctrs_delay()
    print("Delay SLR n2 = %d" % delay[2])
    print("Delay SLR n1 = %d" % delay[1])
    print("Delay SLR n0 = %d" % delay[0])

# -------------------------------------------------------------------------------------
# -----------------------------------PRE-SCALER TEST-----------------------------------
# -------------------------------------------------------------------------------------
if args.test == 'prescaler':
    # load data from PaternProducer metadata
    algo_data = np.loadtxt('Pattern_files/metadata/Prescaler_test/algo_rep.txt')
    index = algo_data[0]
    repetitions = algo_data[1]

    o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
    HWtest.hw.dispatch()
    print("Current orbit counter = %d" % np.array(o_ctr))

    # Set the bxmasks, mask everything that is not in the input window (set bt EMP FWK limitations)
    bxmask = np.zeros((3, 18, 4096), dtype=np.uint32)
    bxmask[0:3, 0:18, 0:113] = (2 ** 32 - 1) * np.ones((18, 113), dtype=np.uint32)

    if args.simulation:
        print("Using default BXmask")
    else:
        HWtest.load_BXmask_arr(bxmask)

    # Set the trigger masks as a pass though
    trigger_mask = np.ones((3, 144), dtype=np.uint32) * 2 ** 32 - 1

    HWtest.load_mask_arr(trigger_mask)

    ls_trigg_mark_before = HWtest.read_lumi_sec_trigger_mask_mark()

    HWtest.send_new_trigger_mask_flag()
    for i in range(20):
        ls_trigg_mark_after = HWtest.read_lumi_sec_trigger_mask_mark()
    format_row = "{:>20}" * 3
    print(format_row.format('', 'LS Mark Before', 'LS Mark After'))
    print(format_row.format('Trigger mask SLR n0', ls_trigg_mark_before[0], ls_trigg_mark_after[0]))
    print(format_row.format('Trigger mask SLR n1', ls_trigg_mark_before[1], ls_trigg_mark_after[1]))
    print(format_row.format('Trigger mask SLR n2', ls_trigg_mark_before[2], ls_trigg_mark_after[2]))

    # Set the veto mask
    veto_mask = np.zeros((3, 18), dtype=np.uint32)

    HWtest.load_veto_mask(veto_mask)

    ls_veto_mark_before = HWtest.read_lumi_sec_veto_mask_mark()
    HWtest.send_new_veto_mask_flag()
    for i in range(20):
        ls_veto_mark_after = HWtest.read_lumi_sec_veto_mask_mark()
    print(format_row.format('Veto mask SLR n0', ls_veto_mark_before[0], ls_veto_mark_after[0]))
    print(format_row.format('Veto mask SLR n1', ls_veto_mark_before[1], ls_veto_mark_after[1]))
    print(format_row.format('Veto mask SLR n2', ls_veto_mark_before[2], ls_veto_mark_after[2]))

    prsc_fct = np.uint32(100 * np.ones((3, 576)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((3, 576)))  # 1.00

    index_low = index[np.where(index < 576)[0]]
    index_mid = index[np.where((index >= 576) & (index < 1152))[0]]
    index_high = index[np.where((index >= 1152) & (index < 1728))[0]]

    if args.ps_column == "random":
        prsc_fct[2][np.int16(index_high - 1152)] = np.uint32(np.random.randint(100, 2 ** 24 - 101, len(index_high)))
        prsc_fct[1][np.int16(index_mid - 576)] = np.uint32(np.random.randint(100, 2 ** 24 - 101, len(index_mid)))
        prsc_fct[0][np.int16(index_low)] = np.uint32(np.random.randint(100, 2 ** 24 - 101, len(index_low)))
    elif args.ps_column == "linear":
        prsc_fct[2][np.int16(index_high - 1152)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index_high)))
        prsc_fct[1][np.int16(index_mid - 576)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index_mid)))
        prsc_fct[0][np.int16(index_low)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index_low)))

    HWtest.load_prsc_in_RAM(prsc_fct, 0)

    if args.ps_column == "random":
        prsc_fct_prvw[2][np.int16(index_high - 1152)] = np.uint32(np.random.randint(100, 2 ** 24 - 101, len(index_high)))
        prsc_fct_prvw[1][np.int16(index_mid - 576)] = np.uint32(np.random.randint(100, 2 ** 24 - 101, len(index_mid)))
        prsc_fct_prvw[0][np.int16(index_low)] = np.uint32(np.random.randint(100, 2 ** 24 - 101, len(index_low)))
    elif args.ps_column == "linear":
        prsc_fct_prvw[2][np.int16(index_high - 1152)] = np.uint32(np.linspace(100, 2 ** 24 - 101, len(index_high)))
        prsc_fct_prvw[1][np.int16(index_mid - 576)] = np.uint32(np.linspace(100, 2 ** 24 - 101, len(index_mid)))
        prsc_fct_prvw[0][np.int16(index_low)] = np.uint32(np.linspace(100, 2 ** 24 - 101, len(index_low)))

    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)

    ls_prescale_mark_before = HWtest.read_lumi_sec_prescale_mark()

    HWtest.send_new_prescale_column_flag()
    for i in range(20):
        ls_prescale_mark_after = HWtest.read_lumi_sec_prescale_mark()
    print(format_row.format('Prescaler SLR n0', ls_prescale_mark_before[0], ls_prescale_mark_after[0]))
    print(format_row.format('Prescaler SLR n1', ls_prescale_mark_before[1], ls_prescale_mark_after[1]))
    print(format_row.format('Prescaler SLR n2', ls_prescale_mark_before[2], ls_prescale_mark_after[2]))

    # compute expected rate
    rate_before_theo = np.float64(np.zeros(1728))
    rate_after_theo = np.float64(np.zeros(1728))
    rate_prvw_theo = np.float64(np.zeros(1728))

    rate_before_theo[np.uint32(index)] = np.uint32(repetitions * (2 ** lumi_bit))
    rate_after_theo[np.uint32(index)] = np.uint32(
        repetitions * (2 ** lumi_bit) / prsc_fct.flatten()[np.int16(index)] * 100)
    rate_prvw_theo[np.uint32(index)] = np.uint32(
        repetitions * (2 ** lumi_bit) / prsc_fct_prvw.flatten()[np.int16(index)] * 100)

    # Wait for 2 lumi section, 1 to load the masks and 1 to let the counters actually count
    o_ctr_0 = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
    o_ctr = o_ctr_0
    HWtest.hw.dispatch()
    while (o_ctr - o_ctr_0) < 2 ** (lumi_bit + 1):
        o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
        HWtest.hw.dispatch()

    o_ctr_temp = 0

    error_cnt = 0

    if args.simulation:
        iteration = 2
    else:
        iteration = 5

    for i in range(iteration):
        while ((o_ctr >> lumi_bit) == (o_ctr_temp >> lumi_bit)):
            o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
            HWtest.hw.dispatch()
        o_ctr_temp = o_ctr

        ready_2, ready_1, ready_0 = HWtest.check_counter_ready_flags()
        while not (ready_2 and ready_1 and ready_0):
            print("Counters are not ready to be read")
            time.sleep(5)
            ready_2, ready_1, ready_0 = HWtest.check_counter_ready_flags()

        cnt_before = HWtest.read_cnt_arr(0)
        cnt_after = HWtest.read_cnt_arr(1)
        cnt_prvw = HWtest.read_cnt_arr(2)
        # cnt_pdt = HWtest.read_cnt_arr(3)

        # ttcStatus = ttcNode.readStatus()
        print("Current orbit counter = %d" % o_ctr)

        # if ((ttcStatus.orbitCount - o_ctr_temp) > (2 ** 18)):
        # os.system('clear')
        # print("Current orbit counter = %d" % ttcStatus.orbitCount)
        # o_ctr_temp = ttcStatus.orbitCount
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

    # sys.stdout.flush()

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

    # Set the bxmasks, mask everything that is not in the input window (set bt EMP FWK limitations)
    bxmask = np.zeros((3, 18, 4096), dtype=np.uint32)
    bxmask[0:3, 0:18, 0:113] = (2 ** 32 - 1) * np.ones((18, 113), dtype=np.uint32)

    if args.simulation:
        print("Using default BXmask")
    else:
        HWtest.load_BXmask_arr(bxmask)

    # Set the masks to match trigg_index
    trigger_mask = np.zeros((3, 144), dtype=np.uint32)
    for mask_i, indeces in enumerate(trigg_index):
        for index in indeces:
            if index < 576:
                reg_index = np.uint16(np.floor(index / 32) + mask_i * 18)
                # print(reg_index)
                trigger_mask[0][np.uint16(reg_index)] = trigger_mask[0][np.uint32(reg_index)] | (
                        1 << np.uint32(index - 32 * np.floor(index / 32)))
            # print(hex(trigger_mask[0][np.uint16(reg_index)]))
            elif 576 <= index < 1152:
                reg_index = np.uint16(np.floor((index - 576) / 32) + mask_i * 18)
                # print(reg_index)
                trigger_mask[1][np.uint16(reg_index)] = trigger_mask[1][np.uint32(reg_index)] | (
                        1 << np.uint32((index - 576) - 32 * np.floor((index - 576) / 32)))
            # print(hex(trigger_mask[1][np.uint16(reg_index)]))
            else:
                reg_index = np.uint16(np.floor((index - 1152) / 32) + mask_i * 18)
                # print(reg_index)
                trigger_mask[2][np.uint16(reg_index)] = trigger_mask[2][np.uint32(reg_index)] | (
                        1 << np.uint32((index - 1152) - 32 * np.floor((index - 1152) / 32)))
            # print(hex(trigger_mask[1][np.uint16(reg_index)]))

    HWtest.load_mask_arr(trigger_mask)

    ls_trigg_mark_before = HWtest.read_lumi_sec_trigger_mask_mark()

    HWtest.send_new_trigger_mask_flag()
    for i in range(20):
        ls_trigg_mark_after = HWtest.read_lumi_sec_trigger_mask_mark()
    format_row = "{:>20}" * 3
    print(format_row.format('', 'LS Mark Before', 'LS Mark After'))
    print(format_row.format('Trigger mask SLR n0', ls_trigg_mark_before[0], ls_trigg_mark_after[0]))
    print(format_row.format('Trigger mask SLR n1', ls_trigg_mark_before[1], ls_trigg_mark_after[1]))
    print(format_row.format('Trigger mask SLR n2', ls_trigg_mark_before[2], ls_trigg_mark_after[2]))

    veto_mask = np.zeros((3, 18), dtype=np.uint32)

    HWtest.load_veto_mask(veto_mask)

    ls_veto_mark_before = HWtest.read_lumi_sec_veto_mask_mark()
    HWtest.send_new_veto_mask_flag()
    for i in range(20):
        ls_veto_mark_after = HWtest.read_lumi_sec_veto_mask_mark()
    print(format_row.format('Veto mask SLR n0', ls_veto_mark_before[0], ls_veto_mark_after[0]))
    print(format_row.format('Veto mask SLR n1', ls_veto_mark_before[1], ls_veto_mark_after[1]))
    print(format_row.format('Veto mask SLR n2', ls_veto_mark_before[2], ls_veto_mark_after[2]))

    # Set pre-scaler factors
    prsc_fct = np.uint32(100 * np.ones((3, 576)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((3, 576)))  # 1.00

    HWtest.load_prsc_in_RAM(prsc_fct, 0)
    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)

    ls_prescale_mark_before = HWtest.read_lumi_sec_prescale_mark()

    HWtest.send_new_prescale_column_flag()
    for i in range(20):
        ls_prescale_mark_after = HWtest.read_lumi_sec_prescale_mark()
    print(format_row.format('Prescaler SLR n0', ls_prescale_mark_before[0], ls_prescale_mark_after[0]))
    print(format_row.format('Prescaler SLR n1', ls_prescale_mark_before[1], ls_prescale_mark_after[1]))
    print(format_row.format('Prescaler SLR n2', ls_prescale_mark_before[2], ls_prescale_mark_after[2]))

    # compute expected rate
    trigg_rate_theo = np.float64(np.zeros(8))
    for i in range(8):
        trigg_rate_theo[i] = np.uint32(trigg_rep[i] * (2 ** lumi_bit))

        # Wait for 2 lumi section, 1 to load the masks and 1 to let the counters actually count
    o_ctr_0 = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
    o_ctr = o_ctr_0
    HWtest.hw.dispatch()
    while (o_ctr - o_ctr_0) < 2 ** (lumi_bit + 1):
        o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
        HWtest.hw.dispatch()

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
            o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
            HWtest.hw.dispatch()
        o_ctr_temp = o_ctr

        ready = HWtest.check_trigger_counter_ready_flag()
        while not ready:
            time.sleep(5)
            ready = HWtest.check_trigger_counter_ready_flag()
        # ttcStatus = ttcNode.readStatus()
        # print("Current orbit counter = %d" % o_ctr)

        # if ((ttcStatus.orbitCount - o_ctr_temp) > (2 ** 18)):
        # print("Current orbit counter = %d" % ttcStatus.orbitCount)
        # o_ctr_temp = ttcStatus.orbitCount

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
            # print('Trigger %d-th counter value = %d' % (trigg_index, cnt))
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

    # Set the bxmasks, mask everything that is not in the input window (set bt EMP FWK limitations)
    bxmask = np.zeros((3, 18, 4096), dtype=np.uint32)
    bxmask[0:3, 0:18, 0:113] = (2 ** 32 - 1) * np.ones((18, 113), dtype=np.uint32)

    if args.simulation:
        print("Using default BXmask")
    else:
        HWtest.load_BXmask_arr(bxmask)

    # Set the masks to match trigg_index
    trigger_mask = np.ones((3, 144), dtype=np.uint32) * 2 ** 32 - 1

    HWtest.load_mask_arr(trigger_mask)

    ls_trigg_mark_before = HWtest.read_lumi_sec_trigger_mask_mark()

    HWtest.send_new_trigger_mask_flag()
    for i in range(20):
        ls_trigg_mark_after = HWtest.read_lumi_sec_trigger_mask_mark()
    format_row = "{:>20}" * 3
    print(format_row.format('', 'LS Mark Before', 'LS Mark After'))
    print(format_row.format('Trigger mask SLR n0', ls_trigg_mark_before[0], ls_trigg_mark_after[0]))
    print(format_row.format('Trigger mask SLR n1', ls_trigg_mark_before[1], ls_trigg_mark_after[1]))
    print(format_row.format('Trigger mask SLR n2', ls_trigg_mark_before[2], ls_trigg_mark_after[2]))

    # Set the veto mask
    veto_mask = np.zeros((3, 18), dtype=np.uint32)
    for index in veto_indeces:
        if index < 576:
            reg_index = np.uint16(np.floor(index / 32))
            veto_mask[0][np.uint16(reg_index)] = veto_mask[0][np.uint32(reg_index)] | (
                    1 << np.uint32(index - 32 * np.floor(index / 32)))
        elif 576 <= index < 1152:
            reg_index = np.uint16(np.floor((index - 576) / 32))
            veto_mask[1][np.uint16(reg_index)] = veto_mask[1][np.uint32(reg_index)] | (
                    1 << np.uint32((index - 576) - 32 * np.floor((index - 576) / 32)))
        else:
            reg_index = np.uint16(np.floor((index - 1152) / 32))
            veto_mask[2][np.uint16(reg_index)] = veto_mask[2][np.uint32(reg_index)] | (
                    1 << np.uint32((index - 1152) - 32 * np.floor((index - 1152) / 32)))

    HWtest.load_veto_mask(veto_mask)

    ls_veto_mark_before = HWtest.read_lumi_sec_veto_mask_mark()
    HWtest.send_new_veto_mask_flag()
    for i in range(20):
        ls_veto_mark_after = HWtest.read_lumi_sec_veto_mask_mark()
    print(format_row.format('Veto mask SLR n0', ls_veto_mark_before[0], ls_veto_mark_after[0]))
    print(format_row.format('Veto mask SLR n1', ls_veto_mark_before[1], ls_veto_mark_after[1]))
    print(format_row.format('Veto mask SLR n2', ls_veto_mark_before[2], ls_veto_mark_after[2]))

    # Set pre-scaler factors
    prsc_fct = np.uint32(100 * np.ones((3, 576)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((3, 576)))  # 1.00

    HWtest.load_prsc_in_RAM(prsc_fct, 0)
    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)

    ls_prescale_mark_before = HWtest.read_lumi_sec_prescale_mark()

    HWtest.send_new_prescale_column_flag()
    for i in range(20):
        ls_prescale_mark_after = HWtest.read_lumi_sec_prescale_mark()
    print(format_row.format('Prescaler SLR n0', ls_prescale_mark_before[0], ls_prescale_mark_after[0]))
    print(format_row.format('Prescaler SLR n1', ls_prescale_mark_before[1], ls_prescale_mark_after[1]))
    print(format_row.format('Prescaler SLR n2', ls_prescale_mark_before[2], ls_prescale_mark_after[2]))

    # compute expected rate
    trigg_rate_theo = np.float64(np.zeros(8))
    trigg_rate_with_veto_theo = np.float64(np.zeros(8))
    for i in range(8):
        trigg_rate_theo[i] = np.uint32(finor_cnts * (2 ** lumi_bit))
        trigg_rate_with_veto_theo[i] = np.uint32(finor_with_veto_cnts * (2 ** lumi_bit))
    veto_theo = veto_cnts * (2 ** lumi_bit)

    # Wait for 2 lumi section, 1 to load the masks and 1 to let the counters actually count
    o_ctr_0 = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
    o_ctr = o_ctr_0
    HWtest.hw.dispatch()
    while (o_ctr - o_ctr_0) < 2 ** (lumi_bit + 1):
        o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
        HWtest.hw.dispatch()

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
            o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
            HWtest.hw.dispatch()
        o_ctr_temp = o_ctr

        ready = HWtest.check_trigger_counter_ready_flag()
        while not ready:
            time.sleep(5)
            ready = HWtest.check_trigger_counter_ready_flag()
        # ttcStatus = ttcNode.readStatus()

        # if ((ttcStatus.orbitCount - o_ctr_temp) > (2 ** 18)):
        # print("Current orbit counter = %d" % ttcStatus.orbitCount)
        # o_ctr_temp = ttcStatus.orbitCount

        trigg_cnt = HWtest.read_trigg_cnt(0)
        trigg_cnt_pdt = HWtest.read_trigg_cnt(1)
        trigg_cnt_wveto = HWtest.read_trigg_cnt(4)
        trigg_cnt_pdt_wveto = HWtest.read_trigg_cnt(5)

        veto_cnt_reg = HWtest.read_veto_cnt()

        print(format_row.format('Trigger', *trigg_cnt))
        print(format_row.format('Trigger pdt', *trigg_cnt_pdt))
        print(format_row.format('Trigger vetoed', *trigg_cnt_wveto))
        print(format_row.format('Trigger pdt vetoed', *trigg_cnt_pdt_wveto))

        print('Veto counter value = %d' % (veto_cnt_reg))

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

    bxmask = np.zeros((3, 18, 4096), dtype=np.uint32)

    # set the BX mask accordingly
    for BX_nr in range(np.shape(BX_mask)[1]):
        for index, mask in enumerate(BX_mask[:, BX_nr]):
            if index < 576:
                reg_index = np.uint16(np.floor(index / 32))
                bit_pos = np.uint16(index - reg_index * 32)
                bxmask[0, reg_index, BX_nr] = (bxmask[0, reg_index, BX_nr]) | (np.uint32(mask) << bit_pos)
            elif 576 <= index < 1152:
                reg_index = np.uint16(np.floor((index - 576) / 32))
                bit_pos = np.uint16((index - 576) - reg_index * 32)
                bxmask[1, reg_index, BX_nr] = (bxmask[1, reg_index, BX_nr]) | (np.uint32(mask) << bit_pos)
            else:
                reg_index = np.uint16(np.floor((index - 1152) / 32))
                bit_pos = np.uint16((index - 1152) - reg_index * 32)
                bxmask[2, reg_index, BX_nr] = (bxmask[2, reg_index, BX_nr]) | (np.uint32(mask) << bit_pos)

    HWtest.load_BXmask_arr(bxmask)

    # Set the trigger masks as a pass though
    trigger_mask = np.ones((3, 144), dtype=np.uint32) * 2 ** 32 - 1

    HWtest.load_mask_arr(trigger_mask)

    ls_trigg_mark_before = HWtest.read_lumi_sec_trigger_mask_mark()

    HWtest.send_new_trigger_mask_flag()
    for i in range(20):
        ls_trigg_mark_after = HWtest.read_lumi_sec_trigger_mask_mark()
    format_row = "{:>20}" * 3
    print(format_row.format('', 'LS Mark Before', 'LS Mark After'))
    print(format_row.format('Trigger mask SLR n0', ls_trigg_mark_before[0], ls_trigg_mark_after[0]))
    print(format_row.format('Trigger mask SLR n1', ls_trigg_mark_before[1], ls_trigg_mark_after[1]))

    # Set the veto mask
    veto_mask = np.zeros((3, 18), dtype=np.uint32)

    HWtest.load_veto_mask(veto_mask)

    ls_veto_mark_before = HWtest.read_lumi_sec_veto_mask_mark()
    HWtest.send_new_veto_mask_flag()
    for i in range(20):
        ls_veto_mark_after = HWtest.read_lumi_sec_veto_mask_mark()
    print(format_row.format('Veto mask SLR n0', ls_veto_mark_before[0], ls_veto_mark_after[0]))
    print(format_row.format('Veto mask SLR n1', ls_veto_mark_before[1], ls_veto_mark_after[1]))

    # Set pre-scaler factors
    prsc_fct = np.uint32(100 * np.ones((3, 576)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((3, 576)))  # 1.00

    HWtest.load_prsc_in_RAM(prsc_fct, 0)
    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)

    ls_prescale_mark_before = HWtest.read_lumi_sec_prescale_mark()

    HWtest.send_new_prescale_column_flag()
    for i in range(20):
        ls_prescale_mark_after = HWtest.read_lumi_sec_prescale_mark()
    print(format_row.format('Prescaler SLR n0', ls_prescale_mark_before[0], ls_prescale_mark_after[0]))
    print(format_row.format('Prescaler SLR n1', ls_prescale_mark_before[1], ls_prescale_mark_after[1]))

    # compute expected rate
    rate_before_theo = np.float64(np.zeros(1728))

    rate_before_theo[np.uint32(indeces)] = np.uint32(repetitions * (2 ** lumi_bit))

    # Wait for 2 lumi section, 1 to load the masks and 1 to let the counters actually count
    o_ctr_0 = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
    o_ctr = o_ctr_0
    HWtest.hw.dispatch()
    while (o_ctr - o_ctr_0) < 2 ** (lumi_bit + 1):
        o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
        HWtest.hw.dispatch()

    o_ctr_temp = 0

    error_cnt = 0

    if args.simulation:
        iteration = 2
    else:
        iteration = 5

    for i in range(iteration):
        while ((o_ctr >> lumi_bit) == (o_ctr_temp >> lumi_bit)):
            o_ctr = HWtest.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
            HWtest.hw.dispatch()
        o_ctr_temp = o_ctr

        ready_1, ready_0 = HWtest.check_counter_ready_flags()
        while not (ready_1 and ready_0):
            print("Counters are not ready to be read")
            time.sleep(5)
            ready_1, ready_0 = HWtest.check_counter_ready_flags()

        # ttcStatus = ttcNode.readStatus()
        print("Current orbit counter = %d" % o_ctr)

        # if ((ttcStatus.orbitCount - o_ctr_temp) > (2 ** 18)):
        # os.system('clear')
        # print("Current orbit counter = %d" % ttcStatus.orbitCount)
        # o_ctr_temp = ttcStatus.orbitCount

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

    # TODO maybe put this in a config file? Or directly parse the vhdl pkg?
    unprescaled_low_bits_link = 102
    unprescaled_mid_bits_link = 26
    unprescaled_high_bits_link = 30

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
    temp_data_in = in_valid[len(input_links[1]):(len(input_links[1]) + len(input_links[2]))] * \
                   in_data[len(input_links[1]):(len(input_links[1]) + len(input_links[2]))]

    for i in range(np.shape(input_links)[1]):
        temp_or = np.bitwise_or(temp_or, temp_data_in[i, :])

    output_link_data = []
    for i in range(np.shape(out_data)[1]):
        if out_valid[np.where(links == unprescaled_mid_bits_link), i] == 1:
            output_link_data = np.append(output_link_data, out_data[np.where(links == unprescaled_high_bits_link), i])

    if np.array_equal(output_link_data, temp_or[:len(output_link_data)]):
        print("Mid output algobit pattern match the input data ORing (unprescaled)")
    else:
        raise Exception('Mismatch was found, check your pattern files and/or the registers')


else:
    print('No suitable test was selected!')
