# Collection of functions to access memory resources within P2GT FinOr Serenity board (VU13P).
# Developed  by Gabriele Bortolato (Padova  University)
# gabriele.bortolato@cern.ch

import os

import numpy as np
import random
import uhal
import sys
import time
import argparse



class FinOrController:
    def __init__(self, serenity, connection_file='my_connections.xml', device='x0', emp_flag=False):
        self.serenity = serenity
        self.connection_file = 'file://' + connection_file
        if self.serenity == 'Serenity3':
            self.SLRs = [0, 2]
            self.part = 'vu13p'
        elif self.serenity == 'Serenity2':
            self.SLRs = [0, 2]
            self.part = 'vu9p'
        self.manager = uhal.ConnectionManager(self.connection_file)
        self.hw = self.manager.getDevice(device)
        N_SLR = self.hw.getNode("payload.FINOR_ROREG.N_SLR").read()
        self.hw.dispatch()
        SLR_ALGOS = self.hw.getNode("payload.FINOR_ROREG.N_SLR_ALGOS").read()
        self.hw.dispatch()
        N_ALGOS   = self.hw.getNode("payload.FINOR_ROREG.N_ALGOS").read()
        self.hw.dispatch()
        N_TRIGGERS = self.hw.getNode("payload.FINOR_ROREG.N_TRIGG").read()
        self.hw.dispatch()
        self.slr_algos = np.uint32(SLR_ALGOS)
        self.n_slr = N_SLR
        self.emp_flag = emp_flag

    def set_TimeOutPeriod(self, value):
        self.hw.setTimeoutPeriod(value)

    def get_device(self):
        if self.emp_flag:
            import emp
            device = emp.Controller(self.hw)
            return device
        else:
            print('EMP package was not set')
            return 0

    def get_nr_slr_algos(self):
        return self.slr_algos

    # ==============================READ_WRITE IPbus regs ==============================
    def load_prsc_in_RAM(self, prsc_arr, sel):
        prsc_arr_576 = np.zeros((3, 576), dtype=np.uint32)
        prsc_arr_576[:3, :self.slr_algos] = prsc_arr
        if sel == 0:
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.prescale_factor" % i).writeBlock(prsc_arr_576[i])
            #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.prescale_factor").writeBlock(prsc_arr_576[1])
            #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.prescale_factor").writeBlock(prsc_arr_576[0])
        elif sel == 1:
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.prescale_factor_prvw" % i).writeBlock(prsc_arr_576[i])
            #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.prescale_factor_prvw").writeBlock(prsc_arr_576[1])
            #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.prescale_factor_prvw").writeBlock(prsc_arr_576[0])
        else:
            raise Exception("Selector is not in [0,1]")
        self.hw.dispatch()

    def send_new_prescale_column_flag(self, sel):
        if sel == 0:
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_column" % i).write(0)
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_column" % i).write(1)
            time.sleep(0.01)
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_column" % i).write(0)
            #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
            #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
            #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
            #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(1)
            #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(1)
            #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(1)
            #time.sleep(0.01)
            #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
            #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
            #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
        elif sel == 1:
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column" % i).write(0)
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column" % i).write(1)
            time.sleep(0.01)
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column" % i).write(0)
            #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(0)
            #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(0)
            #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(0)
            #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(1)
            #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(1)
            #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(1)
            #time.sleep(0.01)
            #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(0)
            #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(0)
            #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column").write(0)
        else:
            raise Exception("Selector is not in [0,1]")
        self.hw.dispatch()

    def send_new_trigger_mask_flag(self):
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_trigger_masks" % i).write(
                0)
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_trigger_masks" % i).write(
                1)
        time.sleep(0.01)
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_trigger_masks" % i).write(
                0)
        #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(1)
        #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(1)
        #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(1)
        #time.sleep(0.01)
        #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.dispatch()

    def send_new_veto_mask_flag(self):
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_veto_mask" % i).write(
                0)
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_veto_mask" % i).write(
                1)
        time.sleep(0.01)
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_veto_mask" % i).write(
                0)
        #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(1)
        #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(1)
        #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(1)
        #time.sleep(0.01)
        #self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        self.hw.dispatch()

    def read_lumi_sec_prescale_mark(self, sel):
        mark = np.zeros(self.n_slr)
        if sel == 0:
            for i in range(self.n_slr):
                mark_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_mark" % i).read()
                self.hw.dispatch()
                mark[i] = np.uint32(mark_temp)
            #self.hw.dispatch()
            #mark_2 = self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_mark").read()
            #mark_1 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_mark").read()
            #mark_0 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_mark").read()
        elif sel == 1:
            for i in range(self.n_slr):
                mark_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_preview_mark" % i).read()
                self.hw.dispatch()
                mark[i] = np.uint32(mark_temp)
            #mark_2 = self.hw.getNode(
            #    "payload.SLRn2_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_preview_mark").read()
            #mark_1 = self.hw.getNode(
            #    "payload.SLRn1_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_preview_mark").read()
            #mark_0 = self.hw.getNode(
            #    "payload.SLRn0_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_preview_mark").read()
        else:
            mark = np.zeros(self.n_slr)
            raise Exception("Selector is not in [0,1]")

        return mark

    def read_lumi_sec_trigger_mask_mark(self):
        mark = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            mark_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.stat.lumi_sec_update_trigger_masks_mark" % i).read()
            self.hw.dispatch()
            mark[i] = np.uint32(mark_temp)
        #mark_2 = self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.stat.lumi_sec_update_trigger_masks_mark").read()
        #mark_1 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.stat.lumi_sec_update_trigger_masks_mark").read()
        #mark_0 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.stat.lumi_sec_update_trigger_masks_mark").read()
        #self.hw.dispatch()

        return mark

    def read_lumi_sec_veto_mask_mark(self):
        mark = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            mark_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.stat.lumi_sec_update_veto_mark" % i).read()
            self.hw.dispatch()
            mark[i] = np.uint32(mark_temp)
        #mark_2 = self.hw.getNode("payload.SLRn2_monitor.monitoring_module.CSR.stat.lumi_sec_update_veto_mark").read()
        #mark_1 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.stat.lumi_sec_update_veto_mark").read()
        #mark_0 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.stat.lumi_sec_update_veto_mark").read()
        # self.hw.dispatch()

        return mark

    def load_mask_arr(self, mask_arr):
        trgg_mask_arr_576 = np.zeros((3, 144), dtype=np.uint32)
        trgg_mask_arr_576[0:3, :int(self.slr_algos/32*8)] = mask_arr
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.trgg_mask" % i).writeBlock(trgg_mask_arr_576[i])

        #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.trgg_mask").writeBlock(trgg_mask_arr_576[1])
        #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.trgg_mask").writeBlock(trgg_mask_arr_576[0])
        self.hw.dispatch()

    def load_veto_mask(self, veto_mask):
        veto_mask_576 = np.zeros((3, 18), dtype=np.uint32)
        veto_mask_576[:3, :int(self.slr_algos/32)] = veto_mask
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.veto_mask" % i).writeBlock(veto_mask_576[i])
        #self.hw.getNode("payload.SLRn1_monitor.monitoring_module.veto_mask").writeBlock(veto_mask_576[1])
        #self.hw.getNode("payload.SLRn0_monitor.monitoring_module.veto_mask").writeBlock(veto_mask_576[0])
        self.hw.dispatch()

    def load_BXmask_arr(self, BXmask_arr):
        BXmask_arr_576 = np.zeros((3, 18, 4096), dtype=np.uint32)
        BXmask_arr_576[:3, :int(self.slr_algos/32), :4096] = BXmask_arr
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_0_31").writeBlock(BXmask_arr_576[2][0])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_32_63").writeBlock(BXmask_arr_576[2][1])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_64_95").writeBlock(BXmask_arr_576[2][2])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_96_127").writeBlock(
            BXmask_arr_576[2][3])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_128_159").writeBlock(
            BXmask_arr_576[2][4])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_160_191").writeBlock(
            BXmask_arr_576[2][5])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_192_223").writeBlock(
            BXmask_arr_576[2][6])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_224_255").writeBlock(
            BXmask_arr_576[2][7])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_256_287").writeBlock(
            BXmask_arr_576[2][8])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_288_319").writeBlock(
            BXmask_arr_576[2][9])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_320_351").writeBlock(
            BXmask_arr_576[2][10])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_352_383").writeBlock(
            BXmask_arr_576[2][11])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_384_415").writeBlock(
            BXmask_arr_576[2][12])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_416_447").writeBlock(
            BXmask_arr_576[2][13])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_448_479").writeBlock(
            BXmask_arr_576[2][14])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_480_511").writeBlock(
            BXmask_arr_576[2][15])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_512_543").writeBlock(
            BXmask_arr_576[2][16])
        self.hw.getNode("payload.SLRn2_monitor.monitoring_module.algo_bx_masks.data_544_575").writeBlock(
            BXmask_arr_576[2][17])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_0_31").writeBlock(BXmask_arr_576[1][0])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_32_63").writeBlock(BXmask_arr_576[1][1])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_64_95").writeBlock(BXmask_arr_576[1][2])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_96_127").writeBlock(BXmask_arr_576[1][3])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_128_159").writeBlock(BXmask_arr_576[1][4])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_160_191").writeBlock(BXmask_arr_576[1][5])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_192_223").writeBlock(BXmask_arr_576[1][6])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_224_255").writeBlock(BXmask_arr_576[1][7])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_256_287").writeBlock(BXmask_arr_576[1][8])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_288_319").writeBlock(BXmask_arr_576[1][9])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_320_351").writeBlock(BXmask_arr_576[1][10])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_352_383").writeBlock(BXmask_arr_576[1][11])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_384_415").writeBlock(BXmask_arr_576[1][12])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_416_447").writeBlock(BXmask_arr_576[1][13])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_448_479").writeBlock(BXmask_arr_576[1][14])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_480_511").writeBlock(BXmask_arr_576[1][15])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_512_543").writeBlock(BXmask_arr_576[1][16])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_544_575").writeBlock(BXmask_arr_576[1][17])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_0_31").writeBlock(BXmask_arr_576[0][0])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_32_63").writeBlock(BXmask_arr_576[0][1])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_64_95").writeBlock(BXmask_arr_576[0][2])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_96_127").writeBlock(BXmask_arr_576[0][3])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_128_159").writeBlock(BXmask_arr_576[0][4])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_160_191").writeBlock(BXmask_arr_576[0][5])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_192_223").writeBlock(BXmask_arr_576[0][6])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_224_255").writeBlock(BXmask_arr_576[0][7])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_256_287").writeBlock(BXmask_arr_576[0][8])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_288_319").writeBlock(BXmask_arr_576[0][9])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_320_351").writeBlock(BXmask_arr_576[0][10])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_352_383").writeBlock(BXmask_arr_576[0][11])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_384_415").writeBlock(BXmask_arr_576[0][12])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_416_447").writeBlock(BXmask_arr_576[0][13])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_448_479").writeBlock(BXmask_arr_576[0][14])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_480_511").writeBlock(BXmask_arr_576[0][15])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_512_543").writeBlock(BXmask_arr_576[0][16])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_544_575").writeBlock(BXmask_arr_576[0][17])
        self.hw.dispatch()

    def set_link_mask(self, link_mask):
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.CSR.ctrl.link_mask" % i).write(link_mask[i])
        self.hw.dispatch()
        
    def read_ctrs_delay(self):
        ctrs_delay = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            delay_temp = self.hw.getNode("payload.SLRn%d_monitor.CSR.stat.input_delay" % i).read()
            self.hw.dispatch()
            ctrs_delay[i] = np.uint32(delay_temp)
        
        return ctrs_delay
        
    def check_alignement_error(self):
        align_err = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            err_temp = self.hw.getNode("payload.SLRn%d_monitor.CSR.stat.align_err" % i).read()
            self.hw.dispatch()
            align_err = np.int32(err_temp)

        return align_err

    def reset_alignement_error(self):
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.CSR.ctrl.rst_align_err" % i).write(1)
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.CSR.ctrl.rst_align_err" % i).write(0)
        self.hw.dispatch()

    def load_latancy_delay(self, latency):
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.l1_latency_delay" % i).write(latency)
        self.hw.dispatch()

    def read_latancy_delay(self):
        latency = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            latency_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.l1_latency_delay" % i).read()
            self.hw.dispatch()
            latency[i] = np.uint32(latency_temp)

        return latency

    def check_counter_ready_flags(self):
        ready = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            ready_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.stat.ready" % i).read()
            self.hw.dispatch()
            ready[i] = ready_temp
        return ready

    def read_cnt_arr(self, sel):
        cnt = np.zeros((3, self.slr_algos))
        if sel == 0:
            for i in range(self.n_slr):
                cnt_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.cnt_rate_before_prsc" % i).readBlock(self.slr_algos)
                self.hw.dispatch()
                cnt[i] = cnt_temp
        elif sel == 1:
            for i in range(self.n_slr):
                cnt_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.cnt_rate_after_prsc" % i).readBlock(self.slr_algos)
                self.hw.dispatch()
                cnt[i] = cnt_temp
        elif sel == 2:
            for i in range(self.n_slr):
                cnt_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.cnt_rate_after_prsc_prvw" % i).readBlock(self.slr_algos)
                self.hw.dispatch()
                cnt[i] = cnt_temp
        elif sel == 3:
            for i in range(self.n_slr):
                cnt_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.cnt_rate_pdt" % i).readBlock(self.slr_algos)
                self.hw.dispatch()
                cnt[i] = cnt_temp
        else:
            raise Exception("Selector is not in [0,1,2,3]")
        self.hw.dispatch()
        cnt_out = cnt.flatten()

        return np.array(cnt_out, dtype=np.uint32)

    def check_trigger_counter_ready_flag(self):
        ready = self.hw.getNode("payload.SLR_FINOR.CSR.stat.ready").read()
        self.hw.dispatch()

        return ready

    def read_trigg_cnt(self, sel):
        if sel == 0:
            cnt = self.hw.getNode("payload.SLR_FINOR.cnt_rate_finor").readBlock(8)
        elif sel == 1:
            cnt = self.hw.getNode("payload.SLR_FINOR.cnt_rate_finor_pdt").readBlock(8)
        elif sel == 2:
            cnt = self.hw.getNode("payload.SLR_FINOR.cnt_rate_finor_preview").readBlock(8)
        elif sel == 3:
            cnt = self.hw.getNode("payload.SLR_FINOR.cnt_rate_finor_preview_pdt").readBlock(8)
        elif sel == 4:
            cnt = self.hw.getNode("payload.SLR_FINOR.cnt_rate_finor_with_veto").readBlock(8)
        elif sel == 5:
            cnt = self.hw.getNode("payload.SLR_FINOR.cnt_rate_finor_with_veto_pdt").readBlock(8)
        elif sel == 6:
            cnt = self.hw.getNode("payload.SLR_FINOR.cnt_rate_finor_preview_with_veto").readBlock(8)
        elif sel == 7:
            cnt = self.hw.getNode("payload.SLR_FINOR.cnt_rate_finor_preview_with_veto_pdt").readBlock(8)
        else:
            raise Exception("Selector is not in [0,1,2,3,4,5,6,7]")
        self.hw.dispatch()

        return np.array(cnt, dtype=np.uint32)

    def read_veto_cnt(self):
        cnt = self.hw.getNode("payload.SLR_FINOR.Veto_reg.stat.Veto_cnt").read()
        self.hw.dispatch()

        return cnt

    def read_partial_veto_cnt(self, SLR):
        if  self.n_slr  < SLR < 0:
            raise Exception("SLR number not valid")
        if SLR == 0:
            cnt = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.Veto_reg.stat.Veto_cnt").read()
        elif SLR == 1:
            cnt = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.Veto_reg.stat.Veto_cnt").read()
        elif SLR == 2:
            cnt = self.hw.getNode("payload.SLRn2_monitor.monitoring_module.Veto_reg.stat.Veto_cnt").read()
        self.hw.dispatch()

        return cnt

    def ctrs_delay_resync(self):
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.CSR.ctrl.delay_resync" % i).write(1)
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.CSR.ctrl.delay_resync" % i).write(0)
        self.hw.dispatch()
