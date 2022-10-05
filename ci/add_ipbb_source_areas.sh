#! /bin/env bash

ipbb add git https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.cern.ch/p2-xware/firmware/emp-fwk.git -b v0.6.8
ipbb add git https://gitlab.cern.ch/ttc/legacy_ttc.git -b v2.1
ipbb add git https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.cern.ch/cms-tcds/cms-tcds2-firmware.git -b v0_1_1
ipbb add git https://gitlab.cern.ch/HPTD/tclink.git -r fda0bcf
ipbb add git https://github.com/ipbus/ipbus-firmware -b v1.9
