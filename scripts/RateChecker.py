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

class HWtest_class:
    def __init__(self, serenity, connection_file='my_connections.xml', device='x0'):
        self.serenity = serenity
        self.connection_file = 'file://' + connection_file
        if self.serenity == 'Serenity3':
            self.SLRs = [2,3]
            self.part = 'vu13p'
        elif self.serenity == 'Serenity2':
            self.SLRs = [2,3]
            self.part = 'vu9p'
        self.manager = uhal.ConnectionManager(self.connection_file)
        self.hw = self.manager.getDevice(device)

# ==============================READ_WRITE IPbus regs ==============================
    def load_prsc_in_RAM(self, prsc_arr, sel):
        if sel == 0:
            self.hw.getNode("payload.SLR3_monitor.prescale_factor").writeBlock(prsc_arr[1])
            self.hw.getNode("payload.SLR2_monitor.prescale_factor").writeBlock(prsc_arr[0])
        elif sel == 1:
            self.hw.getNode("payload.SLR3_monitor.prescale_factor_prvw").writeBlock(prsc_arr[1])
            self.hw.getNode("payload.SLR2_monitor.prescale_factor_prvw").writeBlock(prsc_arr[0])
        else:
            raise Exception("Selector is not in [0,1]")
        self.hw.dispatch()

    def send_new_prescale_column_flag(self):
        self.hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_prescale_column").write(0)
        self.hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_prescale_column").write(0)
        self.hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_prescale_column").write(1)
        self.hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_prescale_column").write(1)
        time.sleep(0.01)
        self.hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_prescale_column").write(0)
        self.hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_prescale_column").write(0)
        self.hw.dispatch()

    def send_new_trigger_mask_flag(self):
        self.hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_trigger_masks").write(1)
        self.hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_trigger_masks").write(1)
        time.sleep(0.01)
        self.hw.getNode("payload.SLR3_monitor.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.getNode("payload.SLR2_monitor.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.dispatch()

    def read_lumi_sec_prescale_mark(self):
        mark_3 = self.hw.getNode("payload.SLR3_monitor.CSR.stat.lumi_sec_update_prescaler_mark").read()
        mark_2 = self.hw.getNode("payload.SLR2_monitor.CSR.stat.lumi_sec_update_prescaler_mark").read()
        self.hw.dispatch()

        return np.uint32(mark_2), np.uint32(mark_3)

    def read_lumi_sec_trigger_mask_mark(self):
        mark_3 = self.hw.getNode("payload.SLR3_monitor.CSR.stat.lumi_sec_update_trigger_masks_mark").read()
        mark_2 = self.hw.getNode("payload.SLR2_monitor.CSR.stat.lumi_sec_update_trigger_masks_mark").read()
        self.hw.dispatch()

        return np.uint32(mark_2), np.uint32(mark_3)

    def load_mask_arr(self, mask_arr):
        self.hw.getNode("payload.SLR3_monitor.trgg_mask").writeBlock(mask_arr[1])
        self.hw.getNode("payload.SLR2_monitor.trgg_mask").writeBlock(mask_arr[0])
        self.hw.dispatch()

    def load_BXmask_arr(self, BXmask_arr):
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_0_31"   ).writeBlock(BXmask_arr[1][0])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_32_63"  ).writeBlock(BXmask_arr[1][1])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_64_95"  ).writeBlock(BXmask_arr[1][2])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_96_127" ).writeBlock(BXmask_arr[1][3])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_128_159").writeBlock(BXmask_arr[1][4])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_160_191").writeBlock(BXmask_arr[1][5])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_192_223").writeBlock(BXmask_arr[1][6])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_224_255").writeBlock(BXmask_arr[1][7])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_256_287").writeBlock(BXmask_arr[1][8])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_288_319").writeBlock(BXmask_arr[1][9])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_320_351").writeBlock(BXmask_arr[1][10])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_352_383").writeBlock(BXmask_arr[1][11])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_384_415").writeBlock(BXmask_arr[1][12])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_416_447").writeBlock(BXmask_arr[1][13])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_448_479").writeBlock(BXmask_arr[1][14])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_480_511").writeBlock(BXmask_arr[1][15])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_512_543").writeBlock(BXmask_arr[1][16])
        self.hw.getNode("payload.SLR3_monitor.algo_bx_masks.data_544_575").writeBlock(BXmask_arr[1][17])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_0_31"   ).writeBlock(BXmask_arr[0][0])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_32_63"  ).writeBlock(BXmask_arr[0][1])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_64_95"  ).writeBlock(BXmask_arr[0][2])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_96_127" ).writeBlock(BXmask_arr[0][3])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_128_159").writeBlock(BXmask_arr[0][4])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_160_191").writeBlock(BXmask_arr[0][5])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_192_223").writeBlock(BXmask_arr[0][6])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_224_255").writeBlock(BXmask_arr[0][7])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_256_287").writeBlock(BXmask_arr[0][8])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_288_319").writeBlock(BXmask_arr[0][9])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_320_351").writeBlock(BXmask_arr[0][10])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_352_383").writeBlock(BXmask_arr[0][11])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_384_415").writeBlock(BXmask_arr[0][12])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_416_447").writeBlock(BXmask_arr[0][13])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_448_479").writeBlock(BXmask_arr[0][14])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_480_511").writeBlock(BXmask_arr[0][15])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_512_543").writeBlock(BXmask_arr[0][16])
        self.hw.getNode("payload.SLR2_monitor.algo_bx_masks.data_544_575").writeBlock(BXmask_arr[0][17])
        self.hw.dispatch()

    def load_latancy_delay(self, latency):
        self.hw.getNode("payload.SLR3_monitor.CSR.ctrl.l1_latency_delay").write(latency)
        self.hw.getNode("payload.SLR2_monitor.CSR.ctrl.l1_latency_delay").write(latency)
        self.hw.dispatch()

    def read_cnt_arr(self, sel):
        if sel == 0:
            cnt_1 = self.hw.getNode("payload.SLR3_monitor.cnt_rate_before_prsc").readBlock(576)
            cnt_0 = self.hw.getNode("payload.SLR2_monitor.cnt_rate_before_prsc").readBlock(576)
        elif sel == 1:
            cnt_1 = self.hw.getNode("payload.SLR3_monitor.cnt_rate_after_prsc").readBlock(576)
            cnt_0 = self.hw.getNode("payload.SLR2_monitor.cnt_rate_after_prsc").readBlock(576)
        elif sel == 2:
            cnt_1 = self.hw.getNode("payload.SLR3_monitor.cnt_rate_after_prsc_prvw").readBlock(576)
            cnt_0 = self.hw.getNode("payload.SLR2_monitor.cnt_rate_after_prsc_prvw").readBlock(576)
        elif sel == 3:
            cnt_1 = self.hw.getNode("payload.SLR3_monitor.cnt_rate_pdt").readBlock(576)
            cnt_0 = self.hw.getNode("payload.SLR2_monitor.cnt_rate_pdt").readBlock(576)
        else:
            raise Exception("Selector is not in [0,1,2,3]")

        self.hw.dispatch()
        cnt = np.vstack((cnt_0, cnt_1)).flatten()

        return np.array(cnt, dtype=np.uint32)

    def read_trigg_cnt(self, sel):
        if sel == 0:
            cnt = self.hw.getNode("payload.SLR2_FINOR.cnt_rate_finor").readBlock(8)
        elif sel == 1:
            cnt = self.hw.getNode("payload.SLR2_FINOR.cnt_rate_finor_pdt").readBlock(8)
        else:
            raise Exception("Selector is not in [0,1]")
        self.hw.dispatch()

        return np.array(cnt, dtype=np.uint32)

    def get_device(self):
        device = emp.Controller(self.hw)

        return device


HWtest = HWtest_class('Serenity3', 'my_connections.xml', 'x0')

EMPdevice = HWtest.get_device()
ttcNode   = EMPdevice.getTTC()
# ttcNode.forceBCmd(0x24) #Send test enable command

# Set the l1a-latency delay
l1_latency_delay = int(100)
HWtest.load_latancy_delay(l1_latency_delay)

#-------------------------------------------------------------------------------------
#-----------------------------------PRE-SCALER TEST-----------------------------------
#-------------------------------------------------------------------------------------
if args.test =='prescaler':
    # load data from PaternProducer metadata
    algo_data = np.loadtxt('Pattern_files/metadata/Prescaler_test/algo_rep.txt')
    index = algo_data[0]
    repetitions = algo_data[1]

    # Set the bxmasks
    bxmask = np.empty((2,18,4096), dtype=np.uint32)
    bxmask[0] = (2 ** 32 - 1) * np.ones((18, 4096), dtype=np.uint32)
    bxmask[1] = (2 ** 32 - 1) * np.ones((18, 4096), dtype=np.uint32)

    HWtest.load_BXmask_arr(bxmask)

    # Set the masks
    trigger_mask = np.empty((2,144), dtype=np.uint32)
    trigger_mask[0][0]   = (2 ** 1 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[0][19]  = (2 ** 2 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[0][38]  = (2 ** 3 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[0][57]  = (2 ** 4 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[0][76]  = (2 ** 5 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[0][95]  = (2 ** 6 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[0][114] = (2 ** 7 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[0][133] = (2 ** 8 - 1) * np.ones(1, dtype=np.uint32)

    trigger_mask[1][5]   = (2 ** 30 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[1][25]  = (2 ** 29 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[1][45]  = (2 ** 28 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[1][65]  = (2 ** 27 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[1][85]  = (2 ** 26 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[1][105] = (2 ** 25 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[1][125] = (2 ** 24 - 1) * np.ones(1, dtype=np.uint32)
    trigger_mask[1][143] = (2 ** 23 - 1) * np.ones(1, dtype=np.uint32)

    HWtest.load_mask_arr(trigger_mask)
    
    ls_trigg_mark = HWtest.read_lumi_sec_trigger_mask_mark()
    print("SLR 2 mark = %d" % ls_trigg_mark[0])
    print("SLR 3 mark = %d" % ls_trigg_mark[1])
    
    HWtest.send_new_trigger_mask_flag()
    time.sleep(2)
    
    ls_trigg_mark = HWtest.read_lumi_sec_trigger_mask_mark()
    print("SLR 2 mark = %d" % ls_trigg_mark[0])
    print("SLR 3 mark = %d" % ls_trigg_mark[1])

    prsc_fct      = np.uint32(100 * np.ones((2,576)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((2,576)))  # 1.00

    index_low  = index[np.where(index < 576)[0]]
    index_high = index[np.where(index >= 576)[0]]

    if args.ps_column == "random":
        prsc_fct[1][np.int16(index_high - 576)] = np.uint32(np.random.randint(100, 2 ** 24, len(index_high)))
        prsc_fct[0][np.int16(index_low)] = np.uint32(np.random.randint(100, 2 ** 24, len(index_low)))
    elif args.ps_column == "linear":
        prsc_fct[1][np.int16(index_high - 576)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index_high)))
        prsc_fct[0][np.int16(index_low)] = np.int32(np.linspace(100, 2 ** 24 - 101, len(index_low)))

    HWtest.load_prsc_in_RAM(prsc_fct, 0)

    if args.ps_column == "random":
        prsc_fct_prvw[1][np.int16(index_high - 576)] = np.uint32(np.random.randint(100, 2 ** 24, len(index_high)))
        prsc_fct_prvw[0][np.int16(index_low)] = np.uint32(np.random.randint(100, 2 ** 24, len(index_low)))
    elif args.ps_column == "linear":
        prsc_fct_prvw[1][np.int16(index_high - 576)] = np.uint32(np.linspace(100, 2 ** 24 - 1, len(index_high)))
        prsc_fct_prvw[0][np.int16(index_low)] = np.uint32(np.linspace(100, 2 ** 24 - 1, len(index_low)))

    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)
    
    ls_prescale_mark = HWtest.read_lumi_sec_prescale_mark()
    print("SLR 2 mark = %d" % ls_prescale_mark[0])
    print("SLR 3 mark = %d" % ls_prescale_mark[1])
    
    HWtest.send_new_prescale_column_flag()
    time.sleep(2)
    
    ls_prescale_mark = HWtest.read_lumi_sec_prescale_mark()
    print("SLR 2 mark = %d" % ls_prescale_mark[0])
    print("SLR 3 mark = %d" % ls_prescale_mark[1])


    cnt_before = HWtest.read_cnt_arr(0)
    cnt_after  = HWtest.read_cnt_arr(1)
    cnt_prvw   = HWtest.read_cnt_arr(2)
    cnt_pdt    = HWtest.read_cnt_arr(3)

    # compute expected rate
    rate_before_theo = np.float64(np.zeros(1152))
    rate_after_theo = np.float64(np.zeros(1152))
    rate_prvw_theo = np.float64(np.zeros(1152))

    rate_before_theo[np.uint32(index)] = np.uint32(repetitions * (2 ** 18))
    rate_after_theo[np.uint32(index)] = np.uint32(repetitions * (2 ** 18) / prsc_fct.flatten()[np.int16(index)] * 100)
    rate_prvw_theo[np.uint32(index)] = np.uint32(repetitions * (2 ** 18) / prsc_fct_prvw.flatten()[np.int16(index)] * 100)


    time.sleep(47)

    o_ctr_temp = 0

    for i in range(0, 200):

        ttcStatus = ttcNode.readStatus()
        time.sleep(1)
        if ((ttcStatus.orbitCount - o_ctr_temp) > (2 ** 18)):
            os.system('clear')
            print("Current orbit counter = %d" % ttcStatus.orbitCount)
            o_ctr_temp = ttcStatus.orbitCount

            cnt_before = HWtest.read_cnt_arr(0)
            cnt_after = HWtest.read_cnt_arr(1)
            cnt_prvw = HWtest.read_cnt_arr(2)
            cnt_pdt = HWtest.read_cnt_arr(3)

            trigg_cnt = HWtest.read_trigg_cnt(0)
            trigg_cnt_pdt = HWtest.read_trigg_cnt(1)

            rate_before_exp = cnt_before
            rate_after_exp = cnt_after
            rate_prvw_exp = cnt_prvw

            error_before = np.abs(rate_before_exp - rate_before_theo)
            error_after = np.abs(rate_after_exp - rate_after_theo)
            error_preview = np.abs(rate_prvw_exp - rate_prvw_theo)

            for current_i, error in enumerate(error_before):
                if error > 1:
                    print('Mismatch found on rate before pescaler %d, error= %d' % (current_i, error))
                    print('Expected value %d, Value got= %d' % (rate_before_theo[current_i], rate_before_exp[current_i]))
            for current_i, error in enumerate(error_after):
                if error > 1:
                    print('Mismatch found on rate after pescaler %d, error= %d' % (current_i, error))
                    print('Expected value %d, Value got= %d' % (rate_after_theo[current_i], rate_after_exp[current_i]))
            for current_i, error in enumerate(error_preview):
                if error > 1:
                    print('Mismatch found on rate after pescaler preview %d, error= %d' % (current_i, error))
                    print('Expected value %d, Value got= %d' % (rate_prvw_theo[current_i], rate_prvw_exp[current_i]))


        sys.stdout.flush()


    ls_trigg_mark = HWtest.read_lumi_sec_trigger_mask_mark()
    print("SLR 2 mark = %d" % ls_trigg_mark[0])
    print("SLR 3 mark = %d" % ls_trigg_mark[1])

    ls_prescale_mark = HWtest.read_lumi_sec_prescale_mark()
    print("SLR 2 mark = %d" % ls_prescale_mark[0])
    print("SLR 3 mark = %d" % ls_prescale_mark[1])


#-------------------------------------------------------------------------------------
#-----------------------------------TRIGG MASK TEST-----------------------------------
#-------------------------------------------------------------------------------------
elif args.test == 'trigger_mask':

    # load data from PaternProducer metadata
    trigg_index = np.loadtxt('Pattern_files/metadata/Trigg_mask_test/trigg_index.txt')
    trigg_rep   = np.loadtxt('Pattern_files/metadata/Trigg_mask_test/trigg_rep.txt')

    bxmask = np.empty((2, 18, 4096), dtype=np.uint32)
    bxmask[0] = (2 ** 32 - 1) * np.ones((18, 4096), dtype=np.uint32)
    bxmask[1] = (2 ** 32 - 1) * np.ones((18, 4096), dtype=np.uint32)

    HWtest.load_BXmask_arr(bxmask)
    # Set the masks to match trigg_index
    trigger_mask = np.zeros((2, 144), dtype=np.uint32)
    for mask_i, indeces in enumerate(trigg_index):
        for index in indeces:
            if index < 576:
                reg_index = np.uint16(np.floor(index/32) + mask_i * 18)
                print(reg_index)
                trigger_mask[0][np.uint16(reg_index)] = trigger_mask[0][np.uint32(reg_index)] | (1 << np.uint32(index - 32*np.floor(index/32)))
                print(hex(trigger_mask[0][np.uint16(reg_index)]))
            else:
                reg_index = np.uint16(np.floor((index-576)/32) + mask_i * 18)
                print(reg_index)
                trigger_mask[1][np.uint16(reg_index)] = trigger_mask[1][np.uint32(reg_index)] | (1 << np.uint32((index-576) - 32 * np.floor((index-576)/32)))
                print(hex(trigger_mask[1][np.uint16(reg_index)]))

    # Set pre-scaler factors
    prsc_fct = np.uint32(100 * np.ones((2, 576)))  # 1.00
    prsc_fct_prvw = np.uint32(100 * np.ones((2, 576)))  # 1.00


    HWtest.load_prsc_in_RAM(prsc_fct, 0)
    HWtest.load_prsc_in_RAM(prsc_fct_prvw, 1)

    ls_prescale_mark = HWtest.read_lumi_sec_prescale_mark()
    print("SLR 2 mark = %d" % ls_prescale_mark[0])
    print("SLR 3 mark = %d" % ls_prescale_mark[1])
    
    HWtest.send_new_prescale_column_flag()
    time.sleep(2)
    
    ls_prescale_mark = HWtest.read_lumi_sec_prescale_mark()
    print("SLR 2 mark = %d" % ls_prescale_mark[0])
    print("SLR 3 mark = %d" % ls_prescale_mark[1])

    HWtest.load_mask_arr(trigger_mask)

    ls_trigg_mark = HWtest.read_lumi_sec_trigger_mask_mark()
    print("SLR 2 mark = %d" % ls_trigg_mark[0])
    print("SLR 3 mark = %d" % ls_trigg_mark[1])
    
    HWtest.send_new_trigger_mask_flag()
    time.sleep(2)
    
    ls_trigg_mark = HWtest.read_lumi_sec_trigger_mask_mark()
    print("SLR 2 mark = %d" % ls_trigg_mark[0])
    print("SLR 3 mark = %d" % ls_trigg_mark[1])

    # Read counters from board
    cnt_before = HWtest.read_cnt_arr(0)
    cnt_after = HWtest.read_cnt_arr(1)
    cnt_prvw = HWtest.read_cnt_arr(2)
    cnt_pdt = HWtest.read_cnt_arr(3)

    # compute expected rate
    trigg_rate_theo = np.float64(np.zeros(8))
    for i in range(8):
        trigg_rate_theo[i] = np.uint32(trigg_rep[i] * (2 ** 18))

    time.sleep(47)

    o_ctr_temp = 0

    for i in range(0, 200):

        ttcStatus = ttcNode.readStatus()
        time.sleep(1)
        if ((ttcStatus.orbitCount - o_ctr_temp) > (2 ** 18)):
            os.system('clear')
            print("Current orbit counter = %d" % ttcStatus.orbitCount)
            o_ctr_temp = ttcStatus.orbitCount

            trigg_cnt     = HWtest.read_trigg_cnt(0)
            trigg_cnt_pdt = HWtest.read_trigg_cnt(1)

            for trigg_index, cnt in enumerate(trigg_cnt):
                error_trgg = np.abs(trigg_rate_theo[trigg_index] - cnt)
                print('Trigger %d-th counter value = %d' % (trigg_index, cnt))
                if error_trgg > 1:
                    print('Mismatch found on %d-th trigger rate, error= %d' % (trigg_index, error_trgg))
                    print('Expected value %d, Value got= %d' % (trigg_rate_theo[trigg_index], trigg_cnt[trigg_index]))

            for trigg_index, cnt in enumerate(trigg_cnt_pdt):
                print('Trigger %d-th counter post dead time value = %d' % (trigg_index, cnt))

            sys.stdout.flush()
