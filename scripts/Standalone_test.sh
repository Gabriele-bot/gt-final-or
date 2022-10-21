#!/bin/bash

echo "Username: $1";
echo "Board: $2";

python PatternProducer.py -i 4 -s $2


if [ $2 = 'Serenity1' ]
then
    scp -r Pattern_files $1@CMS-L1T-SERENITY-1:$1/Finor/
    scp  RateChecker.py $1@CMS-L1T-SERENITY-1:$1/Finor/
    ssh $1@CMS-L1T-SERENITY-1  "export PATH=/opt/cactus/bin/uhal/tools:$PATH LD_LIBRARY_PATH=/opt/cactus/lib:$LD_LIBRARY_PATH &&
    LD_LIBRARY_PATH=/opt/cactus/lib:$LD_LIBRARY_PATH &&
    export LD_LIBRARY_PATH=/opt/cactus/lib:/opt/smash/lib:$LD_LIBRARY_PATH &&
    export PATH=/opt/cactus/bin/emp:$PATH &&
    export SMASH_PATH=/opt/smash &&
    export PATH=/opt/cactus/bin/emp:/opt/cactus/bin/serenity:$PATH &&
    cd $1/Finor/ &&
    serenitybutler power off x0 &&
    serenitybutler power on x0 &&
    serenitybutler program x0 gt-final-or.bit -r &&
    empbutler -c my_connections.xml do x0 reset internal &&
    empbutler -c my_connections.xml do x0 buffers rx PlayOnce -c 4-15,44-55,64-75,104-115 --inject file://Pattern_files/Finor_input_pattern.txt &&
    empbutler -c my_connections.xml do x0 buffers tx Capture -c 0-120 && 
    empbutler -c my_connections.xml do x0 capture --tx 0-120 && 
    python RateChecker.py  &&
    serenitybutler power off x0 &&
    exit" 
elif [ $2 = 'Serenity2' ]
then
    scp -r Pattern_files $1@CMS-L1T-SERENITY-2:$1/Finor/
    scp  RateChecker.py $1@CMS-L1T-SERENITY-2:$1/Finor/
    ssh $1@CMS-L1T-SERENITY-2 "export PATH=/opt/cactus/bin/uhal/tools:$PATH LD_LIBRARY_PATH=/opt/cactus/lib:$LD_LIBRARY_PATH &&
    export LD_LIBRARY_PATH=/opt/cactus/lib:/opt/smash/lib:$LD_LIBRARY_PATH &&
    export PATH=/opt/cactus/bin/emp:$PATH &&
    export SMASH_PATH=/opt/smash &&
    export PATH=/opt/cactus/bin/emp:/opt/cactus/bin/serenity:$PATH &&
    cd $1/Finor/ &&
    serenitybutler power off x0 &&
    serenitybutler power on x0 &&
    serenitybutler program x0 gt-final-or.bit -r &&
    empbutler -c my_connections.xml do x0 reset internal &&
    empbutler -c my_connections.xml do x0 buffers rx PlayOnce -c 4-15,44-55,64-75,104-115 --inject file://Pattern_files/Finor_input_pattern.txt &&
    empbutler -c my_connections.xml do x0 buffers tx Capture -c 0-120 && 
    empbutler -c my_connections.xml do x0 capture --tx 0-120 && 
    python RateChecker.py  &&
    serenitybutler power off x0 &&
    exit"
    
elif [ $2 = 'Serenity3' ]
then
    scp -r Pattern_files $1@CMS-L1T-SERENITY-3:$1/Finor/
    scp  RateChecker.py $1@CMS-L1T-SERENITY-3:$1/Finor/
    ssh $1@CMS-L1T-SERENITY-3 "export PATH=/opt/cactus/bin/uhal/tools:$PATH LD_LIBRARY_PATH=/opt/cactus/lib:$LD_LIBRARY_PATH &&
    LD_LIBRARY_PATH=/opt/cactus/lib:$LD_LIBRARY_PATH &&
    export LD_LIBRARY_PATH=/opt/cactus/lib:/opt/smash/lib:$LD_LIBRARY_PATH &&
    export PATH=/opt/cactus/bin/emp:$PATH &&
    export SMASH_PATH=/opt/smash &&
    export PATH=/opt/cactus/bin/emp:/opt/cactus/bin/serenity:$PATH &&
    cd $1/Finor/ &&
    serenitybutler power off x0 &&
    serenitybutler power on x0 &&
    serenitybutler program x0 p2gt_finor_serenity-vu13p.bit -r &&
    empbutler -c my_connections.xml do x0 reset internal &&
    empbutler -c my_connections.xml do x0 buffers rx PlayOnce -c 36-47,48-59,68-79,80-91 --inject file://Pattern_files/Finor_input_pattern.txt &&
    empbutler -c my_connections.xml do x0 buffers tx Capture -c 0-127 && 
    empbutler -c my_connections.xml do x0 capture --tx 0-127 && 
    python RateChecker.py -t random &&
    serenitybutler power off x0 &&
    exit"
fi
