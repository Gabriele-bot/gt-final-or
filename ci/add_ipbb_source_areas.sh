#! /bin/env bash

ipbb add git https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.cern.ch/dth_p1-v2/slinkrocket.git -b v03.10

# If using GBT/lpGBT cores, also run:
ipbb add git https://gitlab.cern.ch/gbt-fpga/gbt-fpga.git -b gbt_fpga_6_1_0
ipbb add git https://gitlab.cern.ch/gbt-fpga/lpgbt-fpga.git -b v.2.1
ipbb add git https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.cern.ch/gbtsc-fpga-support/gbt-sc.git -b gbt_sc_4_1

ipbb add git https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.cern.ch/p2-xware/firmware/emp-fwk.git -b v0.7.3
ipbb add git https://gitlab.cern.ch/ttc/legacy_ttc.git -b v2.1
ipbb add git https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.cern.ch/cms-tcds/cms-tcds2-firmware.git -b v0_1_1
ipbb add git https://gitlab.cern.ch/HPTD/tclink.git -r fda0bcf
ipbb add git https://github.com/ipbus/ipbus-firmware -b v1.9
