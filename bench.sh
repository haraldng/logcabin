#!/bin/bash

# Tries to follow the steps of README.md closely, which helps to keep that file
# up-to-date.

set -ex

tmpdir=$(mktemp -d)
results_dir="./results"
NUM_RUNS=2

# experiment params
entry_size=8	# ~ u64 entry
concurrent_proposals=1 
num_proposals=1000 
election_timeout=1000
leader_hb_period=100

verbosity=SILENT

cat >logcabin-1.conf << EOF
serverId = 1
listenAddresses = 127.0.0.1:5254
storagePath=$tmpdir
logPolicy = SILENT
electionTimeoutMilliseconds=$election_timeout
heartbeatPeriodMilliseconds=$leader_hb_period
storageOpenSegments = 1
snapshotRatio=5000000
snapshotMinLogSize=500000000
EOF

cat >logcabin-2.conf << EOF
serverId = 2
listenAddresses = 127.0.0.1:5255
storagePath=$tmpdir
logPolicy = SILENT
electionTimeoutMilliseconds=$election_timeout
heartbeatPeriodMilliseconds=$leader_hb_period
storageOpenSegments = 1
snapshotRatio=5000000
snapshotMinLogSize=500000000
EOF

cat >logcabin-3.conf << EOF
serverId = 3
listenAddresses = 127.0.0.1:5256
storagePath=$tmpdir
logPolicy = SILENT
electionTimeoutMilliseconds=$election_timeout
heartbeatPeriodMilliseconds=$leader_hb_period
storageOpenSegments = 1
snapshotRatio=5000000
snapshotMinLogSize=500000000
EOF

path=$results_dir/run-$(date +%s%3N)
results_file=logcabin_${num_proposals}_${concurrent_proposals}.out

mkdir -p debug
mkdir -p $path

for (( i=1; i<=$NUM_RUNS; i++ ))
do
	build/LogCabin --config logcabin-1.conf --bootstrap

	build/LogCabin --config logcabin-1.conf --log debug/1 &
	pid1=$!

	build/LogCabin --config logcabin-2.conf --log debug/2 &
	pid2=$!

	build/LogCabin --config logcabin-3.conf --log debug/3 &
	pid3=$!

	ALLSERVERS=127.0.0.1:5254,127.0.0.1:5255,127.0.0.1:5256
	build/Examples/Reconfigure --cluster=$ALLSERVERS set 127.0.0.1:5254 127.0.0.1:5255 127.0.0.1:5256

	build/Examples/Benchmark --cluster=$ALLSERVERS --size=$entry_size --threads=$concurrent_proposals --writes=$num_proposals --verbosity=$verbosity --resultsFile=$path/$results_file

	kill $pid1
	kill $pid2
	kill $pid3

	wait

	rm -r $tmpdir

	echo "run $i finished"
done



