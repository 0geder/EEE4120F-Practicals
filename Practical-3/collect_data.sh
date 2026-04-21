#!/bin/bash

cd "/mnt/c/Users/0geda/OneDrive - University of Cape Town/Desktop/Fourth Year/EEE4120F/EEE4120F-Practicals/Practical-3/MPI"

echo "=== MPI Data Collection ==="
echo "Cities,Processes,Run,Comp_Time_ms" > mpi_results.csv

for cities in {4..10}; do
    input_file="input/energy$cities"
    for procs in 1 2 4 8; do
        echo "Testing $cities cities with $procs processes..."
        for run in {1..5}; do
            echo "  Run $run"
            result=$(mpirun -np $procs ./wariara_f_MPI -i $input_file -o output/temp.txt 2>/dev/null | grep "Comp Time")
            comp_time=$(echo $result | grep -o '[0-9]*\.[0-9]*' | tail -1)
            comp_time_ms=$(echo "$comp_time * 1000" | bc -l)
            echo "$cities,$procs,$run,$comp_time_ms" >> mpi_results.csv
        done
    done
done

echo "MPI data collection complete."
