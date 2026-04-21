# EEE4120F Practical 3 — Quick Start Guide

## Directory Layout
```
OpenMP/wariara_freights_route.c   ← Task 1
MPI/wariara_freights_route.c      ← Task 2
test_input.txt                    ← 4-city example from the prac manual
test_input_large.txt              ← 12-city example for speedup benchmarking
```

---

## Task 1 — OpenMP

### Compile
```bash
gcc -O2 -fopenmp OpenMP/wariara_freights_route.c -o openmp_solver
```

### Run
```bash
# Single thread
./openmp_solver -p 1 -i test_input.txt

# 4 threads (large input for meaningful speedup)
./openmp_solver -p 4 -i test_input_large.txt
```

### Speedup benchmarking (bash loop)
```bash
for p in 1 2 4 8; do
    echo "--- $p thread(s) ---"
    ./openmp_solver -p $p -i test_input_large.txt
done
```

### Expected output (4-city example)
```
Min Energy (kWh): 22
Optimal Route   : 1 -> 2 -> 3 -> 4
```

---

## Task 2 — MPI

### Compile
```bash
mpicc -O2 MPI/wariara_freights_route.c -o mpi_solver
```

### Run
```bash
# Single process
mpirun -np 1 ./mpi_solver -p 1 -i test_input.txt

# 4 processes
mpirun -np 4 ./mpi_solver -p 4 -i test_input_large.txt
```

### Speedup benchmarking (bash loop)
```bash
for p in 1 2 4 8; do
    echo "--- $p process(es) ---"
    mpirun -np $p ./mpi_solver -p $p -i test_input_large.txt
done
```

---

## Input File Format
```
N
E[1][2]
E[1][3] E[2][3]
E[1][4] E[2][4] E[3][4]
...
```
Where N = number of client cities and E[i][j] = energy cost between city i and city j.

---

## Speedup Formulas (for your report)
- Speedup S = T1 / Tp
- Computation Speedup = Tcomp,1 / Tcomp,p
- Total Speedup = Ttotal,1 / Ttotal,p
