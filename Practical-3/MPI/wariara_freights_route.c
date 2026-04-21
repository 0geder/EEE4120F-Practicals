// =========================================================================
// Practical 3: Minimum Energy Consumption Freight Route Optimization
// =========================================================================
//
// GROUP NUMBER:
//
// MEMBERS:
//   - Member 1 Nyakallo Peeta, PTXNYA001
//   - Member 2 Samson Okuthe, OKTSAM001

// ========================================================================
//  PART 2: Minimum Energy Consumption Freight Route Optimization using OpenMPI
// =========================================================================


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/time.h>
#include <string.h>
#include <limits.h>
#include "mpi.h"

#define MAX_N 10

// ============================================================================
// Global variables
// ============================================================================

int n; // If this is -1, it signals an error/exit
int adj[MAX_N][MAX_N];

// ── Local best for this process (no locks needed — private per process) ─────
int local_best_cost;
int local_best_path[MAX_N];

// ============================================================================
// Timer: returns time in seconds
// ============================================================================

double gettime()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec / 1000000.0;
}

// ============================================================================
// Usage function
// ============================================================================

void Usage(char *program) {
  printf("Usage: mpirun -np <num> %s [options]\n", program);
  printf("-i <file>\tInput file name\n");
  printf("-o <file>\tOutput file name\n");
  printf("-h \t\tDisplay this help\n");
}

// ============================================================================
// Greedy nearest-neighbour heuristic
// Gives a tight initial upper bound so pruning is aggressive from the start.
// ============================================================================

int greedy_bound(int start_path[MAX_N])
{
    int visited[MAX_N] = {0};
    int cur  = 0;
    int cost = 0;

    start_path[0] = 0;
    visited[0]    = 1;

    for (int step = 1; step < n; step++) {
        int best_next = -1;
        int best_e    = INT_MAX;

        for (int k = 0; k < n; k++) {
            if (!visited[k] && adj[cur][k] < best_e) {
                best_e    = adj[cur][k];
                best_next = k;
            }
        }

        start_path[step]   = best_next;
        visited[best_next] = 1;
        cost += best_e;
        cur   = best_next;
    }

    return cost;
}

// ============================================================================
// Recursive Branch-and-Bound (runs entirely within one process — no MPI here)
//
//   path[]       – cities visited so far (0-indexed)
//   depth        – number of cities currently in path
//   visited[]    – visited[i] = 1 means city i is already in the path
//   current_cost – cumulative energy cost of the partial route
//
// Uses local_best_cost as the bound — no synchronisation needed because
// each MPI process owns its own private copy.
// ============================================================================

void branch_and_bound(int path[], int depth,
                      int visited[], int current_cost)
{
    /* ── Base case: complete route found ── */
    if (depth == n) {
        if (current_cost < local_best_cost) {
            local_best_cost = current_cost;
            memcpy(local_best_path, path, n * sizeof(int));
        }
        return;
    }

    int last = path[depth - 1];

    for (int next = 0; next < n; next++) {

        if (visited[next]) continue;

        int new_cost = current_cost + adj[last][next];

        /* ── Prune: cannot beat local best ── */
        if (new_cost >= local_best_cost) continue;

        /* ── Branch ── */
        visited[next] = 1;
        path[depth]   = next;

        branch_and_bound(path, depth + 1, visited, new_cost);

        /* ── Backtrack ── */
        visited[next] = 0;
    }
}


int main(int argc, char **argv)
{
    int rank, nprocs;
    int opt;
    int i, j;
    char *input_file  = NULL;
    char *output_file = NULL;
    FILE *infile      = NULL;
    FILE *outfile     = NULL;
    int success_flag  = 1; /* 1 = good, 0 = error/help encountered */

    /* ── Record wall-clock start (includes MPI_Init overhead) ── */
    double t_init_start = gettime();

    /* Initialize MPI */
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &nprocs);


    if (rank == 0) {
        n = -1;

        while ((opt = getopt(argc, argv, "i:o:h")) != -1)
        {
            switch (opt)
            {
                case 'i':
                    input_file = optarg;
                    break;

                case 'o':
                    output_file = optarg;
                    break;

                case 'h':
                    Usage(argv[0]);
                    success_flag = 0;
                    break;

                default:
                    Usage(argv[0]);
                    success_flag = 0;
            }
        }

        if (success_flag) {
            infile = fopen(input_file, "r");
            if (infile == NULL) {
                fprintf(stderr, "Error: Cannot open input file '%s'\n", input_file);
                perror("");
                success_flag = 0;
            } else {
                fscanf(infile, "%d", &n);

                for (i = 1; i < n; i++)
                {
                    for (j = 0; j < i; j++)
                    {
                        fscanf(infile, "%d", &adj[i][j]);
                        adj[j][i] = adj[i][j];
                    }
                }
                fclose(infile);
            }
        }
        if (success_flag) {
            outfile = fopen(output_file, "w");
            if (outfile == NULL) {
                fprintf(stderr, "Error: Cannot open output file '%s'\n", output_file);
                perror("");
                success_flag = 0;
            }
        }
    }


    MPI_Bcast(&n, 1, MPI_INT, 0, MPI_COMM_WORLD);

    if (n == -1) {
        MPI_Finalize();
        return 0;
    }

    MPI_Bcast(&adj[0][0], MAX_N * MAX_N, MPI_INT, 0, MPI_COMM_WORLD);

    /* ── Remove the debug matrix print from the template ── */

    double t_init_end = gettime();
    double t_init     = t_init_end - t_init_start;

    /* ────────────────────────────────────────────────────────────────────
     * PARALLEL BRANCH-AND-BOUND
     *
     * Decomposition strategy — static cyclic distribution:
     *   Rank r handles first moves where (first_move - 1) % nprocs == rank
     *
     * Example with nprocs=4, n=9 (8 first moves):
     *   Rank 0: first moves 1, 5
     *   Rank 1: first moves 2, 6
     *   Rank 2: first moves 3, 7
     *   Rank 3: first moves 4, 8
     *
     * Each process runs B&B completely independently with its own private
     * local_best_cost — no locks, no mid-computation communication.
     *
     * After all local work is done:
     *   1. MPI_Reduce (MPI_MINLOC) → rank 0 finds the global minimum
     *   2. Winning rank broadcasts its full path to all processes
     *   3. Rank 0 writes the result to the output file
     * ──────────────────────────────────────────────────────────────────── */

    /* Seed each process with the greedy bound for tighter initial pruning */
    local_best_cost = greedy_bound(local_best_path);

    double t_comp_start = gettime();

    for (int first_move = 1; first_move < n; first_move++) {

        /* Static cyclic: skip moves not assigned to this rank */
        if ((first_move - 1) % nprocs != rank) continue;

        int path[MAX_N];
        int visited[MAX_N];
        memset(visited, 0, sizeof(visited));

        path[0]             = 0;          /* always start at hub (city 0) */
        visited[0]          = 1;
        path[1]             = first_move;
        visited[first_move] = 1;

        int cost = adj[0][first_move];

        /* Top-level prune */
        if (cost < local_best_cost)
            branch_and_bound(path, 2, visited, cost);
    }

    double t_comp_end = gettime();
    double t_comp_local = t_comp_end - t_comp_start;

    /* ────────────────────────────────────────────────────────────────────
     * RESULT COLLECTION
     *
     * MPI_MINLOC on MPI_2INT reduces pairs of {cost, rank} to find
     * the single rank holding the global minimum cost.
     * ──────────────────────────────────────────────────────────────────── */

    /* Pack {cost, rank} for MPI_MINLOC */
    struct { int cost; int rank; } local_pair, global_pair;
    local_pair.cost = local_best_cost;
    local_pair.rank = rank;

    MPI_Reduce(&local_pair, &global_pair, 1, MPI_2INT,
               MPI_MINLOC, 0, MPI_COMM_WORLD);

    /* Broadcast the winning rank to everyone, then winning rank sends path */
    int winning_rank = (rank == 0) ? global_pair.rank : 0;
    MPI_Bcast(&winning_rank, 1, MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Bcast(local_best_path, MAX_N, MPI_INT, winning_rank, MPI_COMM_WORLD);

    /* Collect the worst-case (wall-clock) computation time across all ranks */
    double t_comp_max;
    MPI_Reduce(&t_comp_local, &t_comp_max, 1, MPI_DOUBLE,
               MPI_MAX, 0, MPI_COMM_WORLD);

    /* ────────────────────────────────────────────────────────────────────
     * OUTPUT — rank 0 only, to avoid conflicting file writes
     * ──────────────────────────────────────────────────────────────────── */
    if (rank == 0) {

        int global_best = global_pair.cost;

        /* Write to output file */
        fprintf(outfile, "Minimum Energy Cost: %d kWh\n", global_best);
        fprintf(outfile, "Optimal Route: ");
        for (int k = 0; k < n; k++)
            fprintf(outfile, "%d%s", local_best_path[k] + 1,
                    (k < n - 1) ? " -> " : "\n");
        fclose(outfile);

        /* Print to stdout */
        printf("\n--- Results ---\n");
        printf("Processes       : %d\n", nprocs);
        printf("Cities          : %d\n", n);
        printf("Min Energy (kWh): %d\n", global_best);
        printf("Optimal Route   : ");
        for (int k = 0; k < n; k++)
            printf("%d%s", local_best_path[k] + 1,
                   (k < n - 1) ? " -> " : "\n");

        printf("\n--- Timing ---\n");
        printf("Init Time  (Tinit) : %.6f s\n", t_init);
        printf("Comp Time  (Tcomp) : %.6f s\n", t_comp_max);
        printf("Total Time         : %.6f s\n", t_init + t_comp_max);
    }

    MPI_Finalize();
    return 0;
}