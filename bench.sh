#!/bin/bash

# Tries to follow the steps of README.md closely, which helps to keep that file
# up-to-date.

set -e

tmpdir=$(mktemp -d)
results_dir="./results"
NUM_RUNS=30

# experiment params
entry_size=8	# ~ u64 entry
concurrent_proposals=10000 
num_proposals=10000000 # TODO
election_timeout=5000
leader_hb_period=100
rpcFailureBackoffMilliseconds=2500	# should be election_timeout/2

verbosity=ERROR

run_id=$(date +%s%3N)

cat >logcabin-1.conf << EOF
serverId = 1
listenAddresses = 127.0.0.1:5254
storagePath=$tmpdir
logPolicy = $verbosity
electionTimeoutMilliseconds=$election_timeout
heartbeatPeriodMilliseconds=$leader_hb_period
rpcFailureBackoffMilliseconds=$rpcFailureBackoffMilliseconds
storageOpenSegments = 1
snapshotRatio=5000000
snapshotMinLogSize=500000000
EOF

cat >logcabin-2.conf << EOF
serverId = 2
listenAddresses = 127.0.0.1:5255
storagePath=$tmpdir
logPolicy = $verbosity
electionTimeoutMilliseconds=$election_timeout
heartbeatPeriodMilliseconds=$leader_hb_period
rpcFailureBackoffMilliseconds=$rpcFailureBackoffMilliseconds
storageOpenSegments = 1
snapshotRatio=5000000
snapshotMinLogSize=500000000
EOF

cat >logcabin-3.conf << EOF
serverId = 3
listenAddresses = 127.0.0.1:5256
storagePath=$tmpdir
logPolicy = $verbosity
electionTimeoutMilliseconds=$election_timeout
heartbeatPeriodMilliseconds=$leader_hb_period
rpcFailureBackoffMilliseconds=$rpcFailureBackoffMilliseconds
storageOpenSegments = 1
snapshotRatio=5000000
snapshotMinLogSize=500000000
EOF

path=$results_dir/run-${run_id}
runner_path=logs/run-${run_id}/runner.out

mkdir -p logs/run-${run_id}
touch $runner_path
mkdir -p $path

results_file=logcabin_num_proposals_${num_proposals}_concurrent_proposals_${concurrent_proposals}.out

echo "Running $NUM_RUNS runs: num_proposals: $num_proposals, concurrent_proposals: $concurrent_proposals"
for (( i=1; i<=$NUM_RUNS; i++ ))
do
	start="$(date -u): Starting run $i/$NUM_RUNS."
	echo $start 
	echo $start >> $runner_path

	build/LogCabin --config logcabin-1.conf --bootstrap --log logs/run-${run_id}/server1.out

	build/LogCabin --config logcabin-1.conf --log logs/run-${run_id}/server1.out &
	pid1=$!

	build/LogCabin --config logcabin-2.conf --log logs/run-${run_id}/server2.out &
	pid2=$!

	build/LogCabin --config logcabin-3.conf --log logs/run-${run_id}/server3.out &
	pid3=$!

	ALLSERVERS=127.0.0.1:5254,127.0.0.1:5255,127.0.0.1:5256
	build/Examples/Reconfigure --cluster=$ALLSERVERS --verbosity=$verbosity set 127.0.0.1:5254 127.0.0.1:5255 127.0.0.1:5256 | grep "change result" >> $runner_path

	build/Examples/Benchmark --cluster=$ALLSERVERS --size=$entry_size --threads=$concurrent_proposals --writes=$num_proposals --verbosity=$verbosity --resultsFile=$path/$results_file


	s="$(date -u): run $i/$NUM_RUNS finished."
	echo $s
	echo $s >> $runner_path 

	kill $pid1
	kill $pid2
	kill $pid3

	wait

	rm -r $tmpdir
done
echo "All runs finished." >> $runner_path