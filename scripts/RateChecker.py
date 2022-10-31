# Script for checking pre-scale correct behaviour of the Phase-2 Finor Board.
# Developed  by Gabriele Bortolato (Padova  University)
# gabriele.bortolato@cern.ch

import os

import numpy as np
import random
import uhal
import emp
import sys
import time
import argparse

parser = argparse.ArgumentParser(description='GT-Final OR board Rate Checker')
parser.add_argument('-p', '--ps_column', metavar='N', type=str, default='random',
                    help='random --> random pre-scale values,\nlinear --> equally spaced pre-scale values')
parser.add_argument('-t', '--test', metavar='N', type=str, default='prescaler',
                    help='prescaler --> launch  a prescaler test,\ntrigger_mask --> launch a trigger mask test')

args = parser.parse_args()

uhal.disableLogging()

global manager
global hw

manager = uhal.ConnectionManager("file://my_connections.xml")
hw = manager.getDevice("x0")


######################## READ_WRITE IPbus regs ########################################
def load_prsc_in_RAM(prsc_arr, SLR, sel):
    if SLR == 3:
        if sel == 0:
            hw.getNode("payload.SLR3_monitor.prescale_factor").writeBlock(prsc_arr)
        elif sel == 1:
            hw.getNode("payload.SLR3_monitor.prescale_factor_prvw").writeBlock(prsc_arr)
        else:
            raise Exception("Selector is not in [0,1]")
    elif SLR == 2:
        if sel == 0:
            hw.getNode("payload.SLR2_monitor.prescale_factor").writeBlock(prsc_arr)
        elif sel == 1:
            hw.getNode("payload.SLR2_monitor.prescale_factor_prvw").writeBlock(prsc_arr)
        else:
            raise Exception("Selector is not in [0,1]")
    else:
        raise Exception("Available SLRs are 2 and 3")
    hw.dispatch()


def send_new_prescale_column_flag():
    hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_prescale_column").write(0)
    hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_prescale_column").write(0)
    hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_prescale_column").write(1)
    hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_prescale_column").write(1)
    time.sleep(0.01)
    hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_prescale_column").write(0)
    hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_prescale_column").write(0)
    hw.dispatch()


def request_update_prescale():
    hw.getNode("payload.SLR3_monitor.CSR.ctrl.request_pulse_update").write(0)
    hw.getNode("payload.SLR2_monitor.CSR.ctrl.request_pulse_update").write(0)
    hw.getNode("payload.SLR3_monitor.CSR.ctrl.request_pulse_update").write(1)
    hw.getNode("payload.SLR2_monitor.CSR.ctrl.request_pulse_update").write(1)
    time.sleep(0.01)
    hw.getNode("payload.SLR3_monitor.CSR.ctrl.request_pulse_update").write(0)
    hw.getNode("payload.SLR2_monitor.CSR.ctrl.request_pulse_update").write(0)
    hw.dispatch()


def load_mask_arr(mask_arr, SLR):
    if SLR == 3:
        hw.getNode("payload.SLR3_monitor.trgg_mask").writeBlock(mask_arr)
    elif SLR == 2:
        hw.getNode("payload.SLR2_monitor.trgg_mask").writeBlock(mask_arr)
    else:
        raise Exception("Available SLRs are 2 and 3")
    hw.dispatch()


def load_BXmask_arr(BXmask_arr, SLR):
    if SLR == 3:
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_0_31").writeBlock(BXmask_arr[0])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_32_63").writeBlock(BXmask_arr[1])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_64_95").writeBlock(BXmask_arr[2])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_96_127").writeBlock(BXmask_arr[3])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_128_159").writeBlock(BXmask_arr[4])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_160_191").writeBlock(BXmask_arr[5])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_192_223").writeBlock(BXmask_arr[6])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_224_255").writeBlock(BXmask_arr[7])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_256_287").writeBlock(BXmask_arr[8])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_288_319").writeBlock(BXmask_arr[9])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_320_351").writeBlock(BXmask_arr[10])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_352_383").writeBlock(BXmask_arr[11])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_384_415").writeBlock(BXmask_arr[12])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_416_447").writeBlock(BXmask_arr[13])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_448_479").writeBlock(BXmask_arr[14])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_480_511").writeBlock(BXmask_arr[15])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_512_543").writeBlock(BXmask_arr[16])
        hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_544_575").writeBlock(BXmask_arr[17])
    elif SLR == 2:
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_0_31").writeBlock(BXmask_arr[0])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_32_63").writeBlock(BXmask_arr[1])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_64_95").writeBlock(BXmask_arr[2])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_96_127").writeBlock(BXmask_arr[3])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_128_159").writeBlock(BXmask_arr[4])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_160_191").writeBlock(BXmask_arr[5])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_192_223").writeBlock(BXmask_arr[6])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_224_255").writeBlock(BXmask_arr[7])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_256_287").writeBlock(BXmask_arr[8])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_288_319").writeBlock(BXmask_arr[9])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_320_351").writeBlock(BXmask_arr[10])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_352_383").writeBlock(BXmask_arr[11])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_384_415").writeBlock(BXmask_arr[12])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_416_447").writeBlock(BXmask_arr[13])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_448_479").writeBlock(BXmask_arr[14])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_480_511").writeBlock(BXmask_arr[15])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_512_543").writeBlock(BXmask_arr[16])
        hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_544_575").writeBlock(BXmask_arr[17])
    else:
        raise Exception("Available SLRs are 2 and 3")
    hw.dispatch()


def read_cnt_arr(SLR, sel):
    if SLR == 3:
        if sel == 0:
            cnt = hw.getNode("payload.SLR3_monitor.cnt_rate_before_prsc").readBlock(576)
        elif sel == 1:
            cnt = hw.getNode("payload.SLR3_monitor.cnt_rate_after_prsc").readBlock(576)
        elif sel == 2:
            cnt = hw.getNode("payload.SLR3_monitor.cnt_rate_after_prsc_prvw").readBlock(576)
        elif sel == 3:
            cnt = hw.getNode("payload.SLR3_monitor.cnt_rate_pdt").readBlock(576)
        else:
            raise Exception("Selector is not in [0,1,2,3]")
    elif SLR == 2:
        if sel == 0:
            cnt = hw.getNode("payload.SLR2_monitor.cnt_rate_before_prsc").readBlock(576)
        elif sel == 1:
            cnt = hw.getNode("payload.SLR2_monitor.cnt_rate_after_prsc").readBlock(576)
        elif sel == 2:
            cnt = hw.getNode("payload.SLR2_monitor.cnt_rate_after_prsc_prvw").readBlock(576)
        elif sel == 3:
            cnt = hw.getNode("payload.SLR2_monitor.cnt_rate_pdt").readBlock(576)
        else:
            raise Exception("Selector is not in [0,1,2,3]")
    else:
        raise Exception("Available SLRs are 2 and 3")

    hw.dispatch()
    return np.array(cnt, dtype=np.uint32)


def read_trigg_cnt(sel):
    if sel == 0:
        cnt = hw.getNode("payload.SLR2_FINOR.cnt_rate_finor").readBlock(8)
    elif sel == 1:
        cnt = hw.getNode("payload.SLR2_FINOR.cnt_rate_finor_pdt").readBlock(8)
    else:
        raise Exception("Selector is not in [0,1]")
    hw.dispatch()
    return np.array(cnt, dtype=np.uint32)


EMPdevice = emp.Controller(hw)
ttcNode = EMPdevice.getTTC()
# ttcNode.forceBCmd(0x24) #Send test enable command



#-------------------------------------------------------------------------------------
#-----------------------------------PRE-SCALER TEST-----------------------------------
#-------------------------------------------------------------------------------------
if args.test =='prescaler':
	# load data from PaternProducer metadata
	algo_data = np.loadtxt('Pattern_files/metadata/Prescaler_test/algo_rep.txt')
	index = algo_data[0]
	repetitions = algo_data[1]

	# Set the l1a-latency delay
	l1_latency_delay = int(100)
	hw.getNode("payload.SLR2_monitor.CSR.ctrl.l1_latency_delay").write(l1_latency_delay)
	hw.dispatch()

	# Set the bxmasks
	bxmask_3 = (2 ** 32 - 1) * np.ones((18, 4096), dtype=np.uint32)
	bxmask_2 = (2 ** 32 - 1) * np.ones((18, 4096), dtype=np.uint32)

	# Set the masks
	masks_3 = np.zeros(144, dtype=np.uint32)
	masks_3[0:144] = (2 ** 32 - 1) * np.ones(1, dtype=np.uint32)
	masks_3[0] = (2 ** 1 - 1) * np.ones(1, dtype=np.uint32)
	masks_3[19] = (2 ** 2 - 1) * np.ones(1, dtype=np.uint32)
	masks_3[38] = (2 ** 3 - 1) * np.ones(1, dtype=np.uint32)
	masks_3[57] = (2 ** 4 - 1) * np.ones(1, dtype=np.uint32)
	masks_3[76] = (2 ** 5 - 1) * np.ones(1, dtype=np.uint32)
	masks_3[95] = (2 ** 6 - 1) * np.ones(1, dtype=np.uint32)
	masks_3[114] = (2 ** 7 - 1) * np.ones(1, dtype=np.uint32)
	masks_3[133] = (2 ** 8 - 1) * np.ones(1, dtype=np.uint32)

	load_mask_arr(masks_3, 3)

	masks_2 = np.zeros(144, dtype=np.uint32)
	masks_2[0:144] = (2 ** 32 - 1) * np.ones(1, dtype=np.uint32)
	masks_2[5] = (2 ** 30 - 1) * np.ones(1, dtype=np.uint32)
	masks_2[25] = (2 ** 29 - 1) * np.ones(1, dtype=np.uint32)
	masks_2[45] = (2 ** 28 - 1) * np.ones(1, dtype=np.uint32)
	masks_2[65] = (2 ** 27 - 1) * np.ones(1, dtype=np.uint32)
	masks_2[85] = (2 ** 26 - 1) * np.ones(1, dtype=np.uint32)
	masks_2[105] = (2 ** 25 - 1) * np.ones(1, dtype=np.uint32)
	masks_2[125] = (2 ** 24 - 1) * np.ones(1, dtype=np.uint32)
	masks_2[143] = (2 ** 23 - 1) * np.ones(1, dtype=np.uint32)

	load_mask_arr(masks_2, 2)

	prsc_fct_3      = np.uint32(100 * np.ones(576))  # 1.00
	prsc_fct_2      = np.uint32(100 * np.ones(576))  # 1.00
	prsc_fct_prvw_3 = np.uint32(100 * np.ones(576))  # 1.00
	prsc_fct_prvw_2 = np.uint32(100 * np.ones(576))  # 1.00

	index_low  = index[np.where(index < 576)[0]]
	index_high = index[np.where(index >= 576)[0]]

	if args.ps_column == "random":
	    prsc_fct_3[np.int16(index_high - 576)] = np.uint32(np.random.randint(100, 2 ** 24, len(index_high)))
	    prsc_fct_2[np.int16(index_low)] = np.uint32(np.random.randint(100, 2 ** 24, len(index_low)))
	elif args.ps_column == "linear":
	    prsc_fct_3[np.int16(index_high - 576)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index_high)))
	    prsc_fct_2[np.int16(index_low)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index_low)))

	prsc_fct = np.vstack((prsc_fct_2, prsc_fct_3)).flatten()
	load_prsc_in_RAM(prsc_fct_3, 3, 0)
	load_prsc_in_RAM(prsc_fct_2, 2, 0)

	if args.ps_column == "random":
	    prsc_fct_prvw_3[np.int16(index_high - 576)] = np.uint32(np.random.randint(100, 2 ** 24, len(index_high)))
	    prsc_fct_prvw_2[np.int16(index_low)] = np.uint32(np.random.randint(100, 2 ** 24, len(index_low)))
	elif args.ps_column == "linear":
	    prsc_fct_prvw_3[np.int16(index_high - 576)] = np.uint32(np.linspace(100, 2 ** 24 - 1, len(index_high)))
	    prsc_fct_prvw_2[np.int16(index_low)] = np.uint32(np.linspace(100, 2 ** 24 - 1, len(index_low)))

	prsc_fct_prvw = np.vstack((prsc_fct_prvw_2, prsc_fct_prvw_3)).flatten()
	load_prsc_in_RAM(prsc_fct_prvw_3, 3, 1)
	load_prsc_in_RAM(prsc_fct_prvw_2, 2, 1)

	send_new_prescale_column_flag()

	load_BXmask_arr(bxmask_3, 3)
	load_BXmask_arr(bxmask_2, 2)

	load_mask_arr(masks_3, 3)
	load_mask_arr(masks_2, 2)

	cnt_before_3 = read_cnt_arr(3, 0)
	cnt_before_2 = read_cnt_arr(2, 0)
	cnt_before = np.vstack((cnt_before_2, cnt_before_3)).flatten()
	cnt_after_3 = read_cnt_arr(3, 1)
	cnt_after_2 = read_cnt_arr(2, 1)
	cnt_after = np.vstack((cnt_after_2, cnt_after_3)).flatten()
	cnt_prvw_3 = read_cnt_arr(3, 2)
	cnt_prvw_2 = read_cnt_arr(2, 2)
	cnt_prvw = np.vstack((cnt_prvw_2, cnt_prvw_3)).flatten()
	cnt_pdt_3 = read_cnt_arr(3, 3)
	cnt_pdt_2 = read_cnt_arr(2, 3)
	cnt_pdt = np.vstack((cnt_pdt_2, cnt_pdt_3)).flatten()

	# compute expected rate
	rate_before_theo = np.float64(np.zeros_like(prsc_fct))
	rate_after_theo = np.float64(np.zeros_like(prsc_fct))
	rate_prvw_theo = np.float64(np.zeros_like(prsc_fct))

	rate_before_theo[np.uint32(index)] = np.uint32(repetitions * (2 ** 19))
	rate_after_theo[np.uint32(index)] = np.uint32(repetitions * (2 ** 19) / prsc_fct[np.int16(index)] * 100)
	rate_prvw_theo[np.uint32(index)] = np.uint32(repetitions * (2 ** 19) / prsc_fct_prvw[np.int16(index)] * 100)

	time.sleep(47)

	request_update_prescale()

	time.sleep(47)

	o_ctr_temp = 0

	for i in range(0, 50):

	    ttcStatus = ttcNode.readStatus()
	    time.sleep(1)
	    if ((ttcStatus.orbitCount - o_ctr_temp) > (2 ** 19)):
		os.system('clear')
		print("Current orbit counter = %d" % ttcStatus.orbitCount)
		o_ctr_temp = ttcStatus.orbitCount

		cnt_before_3 = read_cnt_arr(3, 0)
		cnt_before_2 = read_cnt_arr(2, 0)
		cnt_before = np.vstack((cnt_before_2, cnt_before_3)).flatten()
		cnt_after_3 = read_cnt_arr(3, 1)
		cnt_after_2 = read_cnt_arr(2, 1)
		cnt_after = np.vstack((cnt_after_2, cnt_after_3)).flatten()
		cnt_prvw_3 = read_cnt_arr(3, 2)
		cnt_prvw_2 = read_cnt_arr(2, 2)
		cnt_prvw = np.vstack((cnt_prvw_2, cnt_prvw_3)).flatten()
		cnt_pdt_3 = read_cnt_arr(3, 3)
		cnt_pdt_2 = read_cnt_arr(2, 3)
		cnt_pdt = np.vstack((cnt_pdt_2, cnt_pdt_3)).flatten()

		trigg_cnt = read_trigg_cnt(0)
		trigg_cnt_pdt = read_trigg_cnt(1)

		rate_before_exp = cnt_before
		rate_after_exp = cnt_after
		rate_prvw_exp = cnt_prvw

		error_before = np.abs(rate_before_exp - rate_before_theo)
		error_after = np.abs(rate_after_exp - rate_after_theo)
		error_preview = np.abs(rate_prvw_exp - rate_prvw_theo)

		for current_i, error in enumerate(error_before):
		    if error >= 1:
		        print('Mismatch found on rate before pescaler %d, error= %d' % (current_i, error))
		        print('Expected value %d, Value got= %d' % (rate_before_theo[current_i], rate_before_exp[current_i]))
		for current_i, error in enumerate(error_after):
		    if error >= 1:
		        print('Mismatch found on rate after pescaler %d, error= %d' % (current_i, error))
		        print('Expected value %d, Value got= %d' % (rate_after_theo[current_i], rate_after_exp[current_i]))
		for current_i, error in enumerate(error_preview):
		    if error >= 1:
		        print('Mismatch found on rate after pescaler preview %d, error= %d' % (current_i, error))
		        print('Expected value %d, Value got= %d' % (rate_prvw_theo[current_i], rate_prvw_exp[current_i]))
		       
		   
	sys.stdout.flush()

elif args.test =='trigger_mask':
#-------------------------------------------------------------------------------------
#-----------------------------------TRIGG MASK TEST-----------------------------------
#-------------------------------------------------------------------------------------

	# load data from PaternProducer metadata
	trigg_index = np.loadtxt('Pattern_files/metadata/Trigg_mask_test/trigg_index.txt')
	trigg_rep   = np.loadtxt('Pattern_files/metadata/Trigg_mask_test/trigg_rep.txt')

	# Set the bxmasks as a pass through
	bxmask_3 = (2 ** 32 - 1) * np.ones((18, 4096), dtype=np.uint32)
	bxmask_2 = (2 ** 32 - 1) * np.ones((18, 4096), dtype=np.uint32)

	# Set the masks to match trigg_index
	masks_3 = np.zeros(144, dtype=np.uint32)
	masks_2 = np.zeros(144, dtype=np.uint32)

	for mask_i, indeces in enumerate(trigg_index):
	    for index in indeces:
		if index < 576:
		    reg_index = np.uint16(np.floor(index/32) + mask_i * 18)
		    print(reg_index)
		    masks_2[np.uint16(reg_index)] = masks_2[np.uint32(reg_index)] | (1 << np.uint32(index - 32*np.floor(index/32)))
		    print(hex(masks_2[np.uint16(reg_index)]))
		else:
		    reg_index = np.uint16(np.floor((index-576)/32) + mask_i * 18)
		    print(reg_index)
		    masks_3[np.uint16(reg_index)] = masks_3[np.uint32(reg_index)] | (1 << np.uint32((index-576) - 32 * np.floor((index-576)/32)))
		    print(hex(masks_3[np.uint16(reg_index)]))

	# Set pre-scaler factors
	prsc_fct_3 = np.uint32(100 * np.ones(576))  # 1.00
	prsc_fct_2 = np.uint32(100 * np.ones(576))  # 1.00
	prsc_fct_prvw_3 = np.uint32(100 * np.ones(576))  # 1.00
	prsc_fct_prvw_2 = np.uint32(100 * np.ones(576))  # 1.00


	load_prsc_in_RAM(prsc_fct_3, 3, 0)
	load_prsc_in_RAM(prsc_fct_2, 2, 0)
	load_prsc_in_RAM(prsc_fct_prvw_3, 3, 1)
	load_prsc_in_RAM(prsc_fct_prvw_2, 2, 1)

	send_new_prescale_column_flag()

	load_BXmask_arr(bxmask_3, 3)
	load_BXmask_arr(bxmask_2, 2)

	load_mask_arr(masks_3, 3)
	load_mask_arr(masks_2, 2)

	# Read counters from board
	cnt_before_3 = read_cnt_arr(3, 0)
	cnt_before_2 = read_cnt_arr(2, 0)
	cnt_before = np.vstack((cnt_before_2, cnt_before_3)).flatten()
	cnt_after_3 = read_cnt_arr(3, 1)
	cnt_after_2 = read_cnt_arr(2, 1)
	cnt_after = np.vstack((cnt_after_2, cnt_after_3)).flatten()
	cnt_prvw_3 = read_cnt_arr(3, 2)
	cnt_prvw_2 = read_cnt_arr(2, 2)
	cnt_prvw = np.vstack((cnt_prvw_2, cnt_prvw_3)).flatten()
	cnt_pdt_3 = read_cnt_arr(3, 3)
	cnt_pdt_2 = read_cnt_arr(2, 3)
	cnt_pdt = np.vstack((cnt_pdt_2, cnt_pdt_3)).flatten()

	# compute expected rate
	trigg_rate_theo = np.float64(np.zeros(8))
	for i in range(8):
	    trigg_rate_theo[i] = np.uint32(trigg_rep[i] * (2 ** 19))

	time.sleep(47)

	request_update_prescale()

	time.sleep(47)

	o_ctr_temp = 0

	for i in range(0, 200):

	    ttcStatus = ttcNode.readStatus()
	    time.sleep(1)
	    if ((ttcStatus.orbitCount - o_ctr_temp) > (2 ** 19)):
		os.system('clear')
		print("Current orbit counter = %d" % ttcStatus.orbitCount)
		o_ctr_temp = ttcStatus.orbitCount

		trigg_cnt = read_trigg_cnt(0)
		trigg_cnt_pdt = read_trigg_cnt(1)


		for trigg_index, cnt in enumerate(trigg_cnt):
		    error_trgg = np.abs(trigg_rate_theo[trigg_index] - cnt)
		    print('Trigger %d-th counter value = %d' % (trigg_index, cnt))
		    if error_trgg >= 1:
		        print('Mismatch found on %d-th trigger rate, error= %d' % (trigg_index, error_trgg))
		        print('Expected value %d, Value got= %d' % (trigg_rate_theo[trigg_index], trigg_cnt[trigg_index]))

		for trigg_index, cnt in enumerate(trigg_cnt_pdt):
		    print('Trigger %d-th counter post dead time value = %d' % (trigg_index, cnt))
		        
		sys.stdout.flush()
