# Collection of functions to access memory resources within P2GT FinOr Serenity board (VU13P).
# Developed  by Gabriele Bortolato (Padova  University)
# gabriele.bortolato@cern.ch

import numpy as np
import uhal
import time


class FinOrController:
    def __init__(self, connection_file='my_connections.xml', device='x0', emp_flag=False):
        self.connection_file = 'file://' + connection_file
        self.SLRs = [0, 2, 3]
        self.manager = uhal.ConnectionManager(self.connection_file)
        self.hw = self.manager.getDevice(device)
        # Get device information
        N_SLR = self.hw.getNode("payload.FINOR_ROREG.N_SLR").read()
        self.hw.dispatch()
        SLR_ALGOS = self.hw.getNode("payload.FINOR_ROREG.N_SLR_ALGOS").read()
        self.hw.dispatch()
        N_ALGOS = self.hw.getNode("payload.FINOR_ROREG.N_ALGOS").read()
        self.hw.dispatch()
        N_TRIGGERS = self.hw.getNode("payload.FINOR_ROREG.N_TRIGG").read()
        self.hw.dispatch()
        self.slr_algos = np.uint32(SLR_ALGOS)
        self.n_slr = np.uint32(N_SLR)
        self.n_algos = np.uint32(N_ALGOS)
        self.emp_flag = emp_flag
        # EMP controller
        if emp_flag:
            import emp
            self.EMPdevice = emp.Controller(self.hw)
            self.ttcNode = self.EMPdevice.getTTC()
        else:
            print("EMP controller not used")

    def read_ttcStatus(self):
        status = self.ttcNode.readStatus()
        return status

    def set_TimeOutPeriod(self, value):
        self.hw.setTimeoutPeriod(value)

    def get_nr_slr_algos(self):
        return self.slr_algos

    def get_bunch_ctr(self):
        if self.emp_flag:
            ttcStatus = self.read_ttcStatus()
            bx_ctr = ttcStatus.bunchCount
        else:
            bx_ctr = self.hw.getNode("ttc.master.common.stat.bunch_ctr").read()
            self.hw.dispatch()
        return bx_ctr

    def get_orbit_ctr(self):
        if self.emp_flag:
            ttcStatus = self.read_ttcStatus()
            o_ctr = ttcStatus.orbitCount
        else:
            o_ctr = self.hw.getNode("ttc.master.common.stat.orbit_ctr").read()
            self.hw.dispatch()
        return o_ctr

    # ==============================READ_WRITE IPbus regs ==============================
    def load_prsc_in_RAM(self, prsc_arr, sel):
        prsc_arr_576 = np.zeros((3, 576), dtype=np.uint32)
        prsc_arr = np.reshape(prsc_arr, (3, self.slr_algos))
        for i in range(self.n_slr):
            prsc_arr_576[i, :self.slr_algos] = prsc_arr[i]
        if sel == 0:
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.prescale_factor" % i).writeBlock(
                    prsc_arr_576[i])
        elif sel == 1:
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.prescale_factor_prvw" % i).writeBlock(
                    prsc_arr_576[i])
        else:
            raise Exception("Selector is not in [0,1]")
        self.hw.dispatch()

    def get_output_ch_number(self, SLR=0):
        if self.n_slr < SLR < 0:
            raise Exception("SLR number not valid")
        uprescaled_ch = self.hw.getNode("payload.FINOR_ROREG.SLRn%d_unprescaled_algo_ch" % SLR).read()
        afterxmask_ch = self.hw.getNode("payload.FINOR_ROREG.SLRn%d_afterbxmask_algo_ch" % SLR).read()
        prescaled_ch = self.hw.getNode("payload.FINOR_ROREG.SLRn%d_prescaled_algo_ch" % SLR).read()
        self.hw.dispatch()
        channels = np.array((uprescaled_ch, afterxmask_ch, prescaled_ch), dtype=np.uint32)

        return channels

    def get_finor_output_ch_number(self):
        ch = self.hw.getNode("payload.FINOR_ROREG.Output_ch").read()
        self.hw.dispatch()

        return np.uint32(ch)

    def send_new_prescale_column_flag(self, sel):
        if sel == 0:
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_column" % i).write(0)
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_column" % i).write(1)
            time.sleep(0.01)
            for i in range(self.n_slr):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_column" % i).write(0)
        elif sel == 1:
            for i in range(self.n_slr):
                self.hw.getNode(
                    "payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column" % i).write(0)
            for i in range(self.n_slr):
                self.hw.getNode(
                    "payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column" % i).write(1)
            time.sleep(0.01)
            for i in range(self.n_slr):
                self.hw.getNode(
                    "payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.new_prescale_preview_column" % i).write(0)
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
        self.hw.dispatch()

    def read_lumi_sec_prescale_mark(self, sel):
        mark = np.zeros(self.n_slr)
        if sel == 0:
            for i in range(self.n_slr):
                mark_temp = self.hw.getNode(
                    "payload.SLRn%d_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_mark" % i).read()
                self.hw.dispatch()
                mark[i] = np.uint32(mark_temp)
        elif sel == 1:
            for i in range(self.n_slr):
                mark_temp = self.hw.getNode(
                    "payload.SLRn%d_monitor.monitoring_module.CSR.stat.lumi_sec_update_prescaler_preview_mark" % i).read()
                self.hw.dispatch()
                mark[i] = np.uint32(mark_temp)
        else:
            raise Exception("Selector is not in [0,1]")

        return mark

    def read_lumi_sec_trigger_mask_mark(self):
        mark = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            mark_temp = self.hw.getNode(
                "payload.SLRn%d_monitor.monitoring_module.CSR.stat.lumi_sec_update_trigger_masks_mark" % i).read()
            self.hw.dispatch()
            mark[i] = np.uint32(mark_temp)

        return mark

    def read_lumi_sec_veto_mask_mark(self):
        mark = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            mark_temp = self.hw.getNode(
                "payload.SLRn%d_monitor.monitoring_module.CSR.stat.lumi_sec_update_veto_mark" % i).read()
            self.hw.dispatch()
            mark[i] = np.uint32(mark_temp)

        return mark

    def convert_index2mask(self, algo_indeces, dim=1):
        mask = np.zeros((dim, 3 * int(np.ceil(self.slr_algos / 32))), dtype=np.uint32)
        if dim == 1:
            for index in algo_indeces:
                reg_index = np.uint16(np.floor(index / 32))
                mask[0][np.uint16(reg_index)] = mask[0][np.uint32(reg_index)] | (
                        1 << np.uint32(index - 32 * np.floor(index / 32)))
        else:
            for mask_i, indeces in enumerate(algo_indeces):
                for index in indeces:
                    reg_index = np.uint16(np.floor(index / 32))
                    mask[mask_i][np.uint16(reg_index)] = mask[mask_i][np.uint32(reg_index)] | (
                            1 << np.uint32(index - 32 * np.floor(index / 32)))

        return mask.reshape((dim, 3, int(np.ceil(self.slr_algos / 32))))

    def load_mask_arr(self, mask_arr):
        trgg_mask_arr_576 = np.zeros((3, 144), dtype=np.uint32)
        for j in range(8):
            for i in range(self.n_slr):
                trgg_mask_arr_576[i, (18 * j):(18 * j + int(np.ceil(self.slr_algos / 32)))] = mask_arr[j, i, :int(
                    np.ceil(self.slr_algos / 32))]
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.trgg_mask" % i).writeBlock(trgg_mask_arr_576[i])
        self.hw.dispatch()

    def load_veto_mask(self, veto_mask):
        veto_mask_576 = np.zeros((3, 18), dtype=np.uint32)
        veto_mask = np.reshape(veto_mask, (3, int(self.slr_algos / 32)))
        veto_mask_576[:3, :int(self.slr_algos / 32)] = veto_mask
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.veto_mask" % i).writeBlock(veto_mask_576[i])
        self.hw.dispatch()

    def load_BXmask_arr(self, BXmask_arr):
        BXmask_arr_576 = np.zeros((3, 18, 4096), dtype=np.uint32)
        BXmask_arr = np.reshape(BXmask_arr, (3, int(self.slr_algos / 32), 4096))
        BXmask_arr_576[:3, :int(self.slr_algos / 32), :4096] = BXmask_arr
        for i in range(self.n_slr):
            for j in range(18):
                self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.algo_bx_masks.data_%d_%d" % (
                    i, j * 32, (j + 1) * 32 - 1)).writeBlock(
                    BXmask_arr_576[i][j])
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
            latency_temp = self.hw.getNode(
                "payload.SLRn%d_monitor.monitoring_module.CSR.ctrl.l1_latency_delay" % i).read()
            self.hw.dispatch()
            latency[i] = np.uint32(latency_temp)

        return latency

    def check_counter_ready_flags(self):
        ready = np.zeros(self.n_slr)
        for i in range(self.n_slr):
            ready_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.CSR.stat.ready" % i).read()
            self.hw.dispatch()
            ready[i] = np.uint32(ready_temp)

        return ready

    def read_cnt_arr(self, sel):
        cnt = np.zeros((3, self.slr_algos))
        if sel == 0:
            for i in range(self.n_slr):
                cnt_temp = self.hw.getNode(
                    "payload.SLRn%d_monitor.monitoring_module.cnt_rate_before_prsc" % i).readBlock(self.slr_algos)
                self.hw.dispatch()
                cnt[i] = cnt_temp
        elif sel == 1:
            for i in range(self.n_slr):
                cnt_temp = self.hw.getNode(
                    "payload.SLRn%d_monitor.monitoring_module.cnt_rate_after_prsc" % i).readBlock(self.slr_algos)
                self.hw.dispatch()
                cnt[i] = cnt_temp
        elif sel == 2:
            for i in range(self.n_slr):
                cnt_temp = self.hw.getNode(
                    "payload.SLRn%d_monitor.monitoring_module.cnt_rate_after_prsc_prvw" % i).readBlock(self.slr_algos)
                self.hw.dispatch()
                cnt[i] = cnt_temp
        elif sel == 3:
            for i in range(self.n_slr):
                cnt_temp = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.cnt_rate_pdt" % i).readBlock(
                    self.slr_algos)
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

        return np.uint32(cnt)

    def read_partial_veto_cnt(self, SLR):
        if self.n_slr < SLR < 0:
            raise Exception("SLR number not valid")
        cnt = self.hw.getNode("payload.SLRn%d_monitor.monitoring_module.Veto_reg.stat.Veto_cnt" % int(SLR)).read()
        self.hw.dispatch()

        return np.uint32(cnt)

    def ctrs_delay_resync(self):
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.CSR.ctrl.delay_resync" % i).write(1)
        for i in range(self.n_slr):
            self.hw.getNode("payload.SLRn%d_monitor.CSR.ctrl.delay_resync" % i).write(0)
        self.hw.dispatch()
