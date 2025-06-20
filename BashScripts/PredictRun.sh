#!/usr/bin/env bash
set -ex
cd ~/Documents/elites2/Analysis

chmod u+r+x ./LLM_GetPredictions.R

ulimit -a 
parallel --number-of-cpus
parallel --number-of-cores
parallel --number-of-threads
parallel --number-of-sockets

# note: this code is primarily used for generate tfrecords (no forward passes) 
#export nParallelJobs=$(echo "scale=0; $(nproc) / 8 + 1" | bc) # the scale part is to round 

export NameTag=$1 # first positional argument to .sh
if [ "$NameTag" = "Studio" ]; then
    export nParallelJobs=1
    export StartAt=1
    export StopAt=1
elif [ "$NameTag" = "M4" ]; then
    export nParallelJobs=1
    export StartAt=1
    export StopAt=1
fi

# ensure tor is running
brew services start tor 

# add nohup and trailing & for screen and disconnect use
nohup parallel --jobs ${nParallelJobs} --joblog ./../BashScripts/logs/PredictRun_${NameTag}_log.txt --load 90% --delay 1 'Rscript --no-save ./LLM_GetPredictions.R {}' ::: $(seq ${StartAt} ${StopAt}) > ./../BashScripts/logs/PredictRun_${NameTag}_out.out 2> ./../BashScripts/logs/PredictRun_${NameTag}_err.err &

