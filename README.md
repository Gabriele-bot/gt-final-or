# FinalOR GT VHDL files
# Supported boards

| Board | FPGA | Depfile name | 
| ---      | ---      | ---      |
| Serenity | VU13P-2-e-flga2577 | `top_serenity_vu13p-so2.d3` |

# Requirements

* Vivado 2020.1 or later
* ipbb 2021j or later
* uHAL[^1]
* Access to the TCDS2 Gitlab repository. (Can be requested at https://cmstcds2.docs.cern.ch/.)
* Access to the EMP repository.

[^1]: https://ipbus.web.cern.ch/doc/user/html/software/installation.html

# Setup instructions

### Get all the required packages
```bash
# If you don't have ipbb installed yet
curl -L https://github.com/ipbus/ipbb/archive/dev/2021j.tar.gz | tar xvz
source ipbb-dev-2021j/env.sh

ipbb init gt-finor-work
cd gt-finor-work
ipbb add git https://:@gitlab.cern.ch:8443/p2-xware/firmware/emp-fwk.git -b v0.7.3
ipbb add git https://github.com/ipbus/ipbus-firmware -b v1.9
ipbb add git https://:@gitlab.cern.ch:8443/cms-tcds/cms-tcds2-firmware.git -b v0_1_1
ipbb add git https://gitlab.cern.ch/HPTD/tclink.git -r fda0bcf
ipbb add git https://gitlab.cern.ch/ttc/legacy_ttc.git -b v2.1
ipbb add git https://:@gitlab.cern.ch:8443/cms-cactus/phase2/firmware/gt-final-or.git
ipbb add git https://gitlab.cern.ch/dth_p1-v2/slinkrocket_ips.git -b v03.09
ipbb add git https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.cern.ch/dth_p1-v2/slinkrocket.git -b v03.10
```

# Build instructions
### Create firmware project
```bash
ipbb proj create vivado gt-final-or gt-final-or:finor-hdl top_serenity_vu13p-so2.d3
cd proj/gt-final-or

# Make uhal tools available
export PATH=/opt/cactus/bin/uhal/tools:$PATH
export LD_LIBRARY_PATH=/opt/cactus/lib:$LD_LIBRARY_PATH

ipbb ipbus gendecoders -f
ipbb vivado generate-project
```

And build it with:

```bash
ipbb vivado synth -j4 impl -j4
ipbb vivado bitfile package
```

# Simulation instructions
Get required packages as in the previous section.

### Generate the pattern files used in the simulation(s)
The input pattern file is generated by a custom python script, it can be found ```scripts/PatternProducer.py```.  
Run the script 
```bash
cd src/gt-final-or/scripts
python PatternProducer.py -i 1152 -s Serenity3
cd ../../..
```

### Create the simulation project (work in progress)
```bash
ipbb proj create sim finor_sim gt-final-or:simulation top_serenity_vu13p-so2.d3
cd proj/finor_sim
ipbb sim setup-simlib
ipbb sim ipcores
ipbb sim fli-udp
ipbb sim addrtab
ipbb sim generate-project
touch design.txt
```

Copy the generated pattern files and scripts in the project directory.
```bash
cp -r ../../src/gt-final-or/scripts .
cp -r addrtab scripts/
cd scripts
echo '<connections>' > my_connections.xml
echo '  <connection id="'x0'" uri="ipbusudp-2.0://localhost:50001" address_table="file://addrtab/sim.xml" />' >> my_connections.xml
echo '</connections>' >> my_connections.xml
cat my_connections.xml
cd ..
```

### Launch the simulation with Questasim
Run one of the commands to enter the command line interface depending on the target test
```bash
vsim -c work.top work.glbl -Gsourcefile=scripts/Pattern_files/Finor_input_pattern_prescaler_test.txt -Gsinkfile=out_prescaler_test.txt
vsim -c work.top work.glbl -Gsourcefile=scripts/Pattern_files/Finor_input_pattern_trigg_test.txt -Gsinkfile=out_trigg_test.txt
vsim -c work.top work.glbl -Gsourcefile=scripts/Pattern_files/Finor_input_pattern_veto_test.txt -Gsinkfile=out_veto_test.txt
vsim -c work.top work.glbl -Gsourcefile=scripts/Pattern_files/Finor_input_pattern_BXmask_test.txt -Gsinkfile=out_BXmask_test.txt
```
To start the simulation use the command
```
run -all
```

To run the simulation in the GUI use the following commands instead
```bash
vsim work.top work.glbl -Gsourcefile=scripts/Pattern_files/Finor_input_pattern_prescaler_test.txt -Gsinkfile=out_prescaler_test.txt
vsim work.top work.glbl -Gsourcefile=scripts/Pattern_files/Finor_input_pattern_trigg_test.txt -Gsinkfile=out_trigg_test.txt
vsim work.top work.glbl -Gsourcefile=scripts/Pattern_files/Finor_input_pattern_veto_test.txt -Gsinkfile=out_veto_test.txt
vsim work.top work.glbl -Gsourcefile=scripts/Pattern_files/Finor_input_pattern_BXmask_test.txt -Gsinkfile=out_BXmask_test.txt
```

### Interact with the simulation with IPbus

Open a new shell in the project folder and go to the `scripts` directory
```bash
cd scripts
```
Launch one of the test available with the command
```bash
pyhton Ratechecker.py -t prescaler -p random -ls 3 -c my_connections -S
pyhton Ratechecker.py -t trigger_mask -p random -ls 3 -c my_connections -S
pyhton Ratechecker.py -t veto_mask -p random -ls 3 -c my_connections -S
pyhton Ratechecker.py -t BXmask -p random -ls 3 -c my_connections -S
```

