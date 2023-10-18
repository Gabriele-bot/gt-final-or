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
import struct


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

print("===============================================")
print("=============TEST SIGNLE ALGO NAME=============")
print("===============================================")

Algo_name = HWtest.get_algo_name(24)
print("Algo name at index %d is: " % 24 + Algo_name)

print("===============================================")
print("===================TEST MENU===================")
print("===============================================")

Menu = HWtest.get_menu()
for i in range(54):
    print("Algo name at index %d is: " % i + Menu[i])



