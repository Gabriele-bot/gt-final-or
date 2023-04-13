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

    # ==============================READ_WRITE IPbus regs ==============================
    def load_prsc_in_RAM(self, prsc_arr, sel):
        if sel == 0:
            self.hw.getNode("payload.SLRn1_monitor.monitoring_module.prescale_factor").writeBlock(prsc_arr[1])
            self.hw.getNode("payload.SLRn0_monitor.monitoring_module.prescale_factor").writeBlock(prsc_arr[0])
        elif sel == 1:
            self.hw.getNode("payload.SLRn1_monitor.monitoring_module.prescale_factor_prvw").writeBlock(prsc_arr[1])
            self.hw.getNode("payload.SLRn0_monitor.monitoring_module.prescale_factor_prvw").writeBlock(prsc_arr[0])
        else:
            raise Exception("Selector is not in [0,1]")
        self.hw.dispatch()

    def send_new_prescale_column_flag(self):
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(1)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(1)
        time.sleep(0.01)
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_prescale_column").write(0)
        self.hw.dispatch()

    def send_new_trigger_mask_flag(self):
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(1)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(1)
        time.sleep(0.01)
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_trigger_masks").write(0)
        self.hw.dispatch()

    def send_new_veto_mask_flag(self):
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(1)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(1)
        time.sleep(0.01)
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.new_veto_mask").write(0)
        self.hw.dispatch()

    def read_lumi_sec_prescale_mark(self):
        mark_3 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_mark").read()
        mark_2 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_mark").read()
        self.hw.dispatch()

        return np.uint32(mark_2), np.uint32(mark_3)

    def read_lumi_sec_trigger_mask_mark(self):
        mark_3 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.stat.lumi_sec_update_trigger_masks_mark").read()
        mark_2 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.stat.lumi_sec_update_trigger_masks_mark").read()
        self.hw.dispatch()

        return np.uint32(mark_2), np.uint32(mark_3)

    def read_lumi_sec_veto_mask_mark(self):
        mark_3 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.stat.lumi_sec_update_veto_mark").read()
        mark_2 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.stat.lumi_sec_update_veto_mark").read()
        self.hw.dispatch()

        return np.uint32(mark_2), np.uint32(mark_3)

    def load_mask_arr(self, mask_arr):
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.trgg_mask").writeBlock(mask_arr[1])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.trgg_mask").writeBlock(mask_arr[0])
        self.hw.dispatch()

    def load_veto_mask(self, veto_mask):
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.veto_mask").writeBlock(veto_mask[1])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.veto_mask").writeBlock(veto_mask[0])
        self.hw.dispatch()

    def load_BXmask_arr(self, BXmask_arr):
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_0_31").writeBlock(BXmask_arr[1][0])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_32_63").writeBlock(BXmask_arr[1][1])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_64_95").writeBlock(BXmask_arr[1][2])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_96_127").writeBlock(BXmask_arr[1][3])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_128_159").writeBlock(BXmask_arr[1][4])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_160_191").writeBlock(BXmask_arr[1][5])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_192_223").writeBlock(BXmask_arr[1][6])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_224_255").writeBlock(BXmask_arr[1][7])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_256_287").writeBlock(BXmask_arr[1][8])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_288_319").writeBlock(BXmask_arr[1][9])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_320_351").writeBlock(BXmask_arr[1][10])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_352_383").writeBlock(BXmask_arr[1][11])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_384_415").writeBlock(BXmask_arr[1][12])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_416_447").writeBlock(BXmask_arr[1][13])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_448_479").writeBlock(BXmask_arr[1][14])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_480_511").writeBlock(BXmask_arr[1][15])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_512_543").writeBlock(BXmask_arr[1][16])
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.algo_bx_masks.data_544_575").writeBlock(BXmask_arr[1][17])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_0_31").writeBlock(BXmask_arr[0][0])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_32_63").writeBlock(BXmask_arr[0][1])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_64_95").writeBlock(BXmask_arr[0][2])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_96_127").writeBlock(BXmask_arr[0][3])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_128_159").writeBlock(BXmask_arr[0][4])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_160_191").writeBlock(BXmask_arr[0][5])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_192_223").writeBlock(BXmask_arr[0][6])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_224_255").writeBlock(BXmask_arr[0][7])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_256_287").writeBlock(BXmask_arr[0][8])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_288_319").writeBlock(BXmask_arr[0][9])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_320_351").writeBlock(BXmask_arr[0][10])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_352_383").writeBlock(BXmask_arr[0][11])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_384_415").writeBlock(BXmask_arr[0][12])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_416_447").writeBlock(BXmask_arr[0][13])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_448_479").writeBlock(BXmask_arr[0][14])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_480_511").writeBlock(BXmask_arr[0][15])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_512_543").writeBlock(BXmask_arr[0][16])
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.algo_bx_masks.data_544_575").writeBlock(BXmask_arr[0][17])
        self.hw.dispatch()

    def set_link_mask(self, link_mask_1, link_mask_0):
        self.hw.getNode("payload.SLRn1_monitor.CSR.ctrl.link_mask").write(link_mask_1)
        self.hw.getNode("payload.SLRn0_monitor.CSR.ctrl.link_mask").write(link_mask_0)
        self.hw.dispatch()
        
    def set_GT_algo_delay(self, algo_delay):
        self.hw.getNode("payload.SLRn1_monitor.CSR.ctrl.GT_algo_delay").write(algo_delay)
        self.hw.getNode("payload.SLRn0_monitor.CSR.ctrl.GT_algo_delay").write(algo_delay)
        self.hw.getNode("payload.SLR_FINOR.CSR.ctrl.GT_finor_delay").write(algo_delay)
        self.hw.dispatch()
        
    def check_alignement_error(self):
        err_1 = self.hw.getNode("payload.SLRn1_monitor.CSR.stat.align_err").read()
        err_0 = self.hw.getNode("payload.SLRn0_monitor.CSR.stat.align_err").read()
        self.hw.dispatch()

        return err_1, err_0

    def reset_alignement_error(self):
        self.hw.getNode("payload.SLRn1_monitor.CSR.ctrl.rst_align_err").write(1)
        self.hw.getNode("payload.SLRn0_monitor.CSR.ctrl.rst_align_err").write(1)
        self.hw.getNode("payload.SLRn1_monitor.CSR.ctrl.rst_align_err").write(0)
        self.hw.getNode("payload.SLRn0_monitor.CSR.ctrl.rst_align_err").write(0)
        self.hw.dispatch()

    def load_latancy_delay(self, latency):
        self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.l1_latency_delay").write(latency)
        self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.l1_latency_delay").write(latency)
        self.hw.dispatch()

    def read_latancy_delay(self):
        latency_3 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.ctrl.l1_latency_delay").read()
        latency_2 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.ctrl.l1_latency_delay").read()
        self.hw.dispatch()

        return latency_2, latency_3

    def check_counter_ready_flags(self):
        ready_1 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.CSR.stat.ready").read()
        ready_0 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.CSR.stat.ready").read()
        self.hw.dispatch()

        return ready_1, ready_0

    def read_cnt_arr(self, sel):
        if sel == 0:
            cnt_1 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.cnt_rate_before_prsc").readBlock(576)
            cnt_0 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.cnt_rate_before_prsc").readBlock(576)
        elif sel == 1:
            cnt_1 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.cnt_rate_after_prsc").readBlock(576)
            cnt_0 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.cnt_rate_after_prsc").readBlock(576)
        elif sel == 2:
            cnt_1 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.cnt_rate_after_prsc_prvw").readBlock(576)
            cnt_0 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.cnt_rate_after_prsc_prvw").readBlock(576)
        elif sel == 3:
            cnt_1 = self.hw.getNode("payload.SLRn1_monitor.monitoring_module.cnt_rate_pdt").readBlock(576)
            cnt_0 = self.hw.getNode("payload.SLRn0_monitor.monitoring_module.cnt_rate_pdt").readBlock(576)
        else:
            raise Exception("Selector is not in [0,1,2,3]")
        self.hw.dispatch()
        cnt = np.vstack((cnt_0, cnt_1)).flatten()

        return np.array(cnt, dtype=np.uint32)

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
