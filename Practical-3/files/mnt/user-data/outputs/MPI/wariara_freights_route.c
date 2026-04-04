/*
 * EEE4120F Practical 3 - Task 2: MPI Branch-and-Bound
 * Wariara Freights Inc. - Minimum Energy Route Solver (Distributed Memory)
 *
 * Compile: mpicc -O2 wariara_freights_route.c -o wariara_freights_route
 * Run:     mpirun -np <num_procs> ./wariara_freights_route -p <num_procs> -i <input_file>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <mpi.h>

/* ─── Timing ─────────────────────────────────────────────────────────────── */
static double gettime(void) { return MPI_Wtime(); }

/* ─── Globals ─────────────────────────────────────────────────────────────── */
#define MAX_CITIES 20
#define TAG_WORK   1
#define TAG_RESULT 2
#define TAG_DONE   3
#define TAG_BOUND  4

int N;
int energy[MAX_CITIES][MAX_CITIES];

/* Local best for this process */
int local_best_cost;
int local_best_path[MAX_CITIES];

/* ─── Recursive Branch-and-Bound (local, no communication) ──────────────── */
void branch_and_bound(int path[], int depth, int visited[], int current_cost)
{
    if (depth == N) {
        if (current_cost < local_best_cost) {
            local_best_cost = current_cost;
            memcpy(local_best_path, path, N * sizeof(int));
        }
        return;
    }

    int last = path[depth - 1];

    for (int next = 0; next < N; next++) {
        if (visited[next]) continue;

        int new_cost = current_cost + energy[last][next];

        if (new_cost >= local_best_cost) continue;   /* prune */

        visited[next] = 1;
        path[depth]   = next;

        branch_and_bound(path, depth + 1, visited, new_cost);

        visited[next] = 0;
    }
}

/* ─── Greedy nearest-neighbour (for initial bound) ──────────────────────── */
static int greedy_bound(void)
{
    int vis[MAX_CITIES] = {0};
    int cur = 0, cost = 0;
    vis[cur] = 1;
    for (int step = 1; step < N; step++) {
        int best_next = -1, best_e = INT_MAX;
        for (int k = 0; k < N; k++) {
            if (!vis[k] && energy[cur][k] < best_e) {
                best_e = energy[cur][k];
                best_next = k;
            }
        }
        vis[best_next] = 1;
        cost += best_e;
        cur = best_next;
    }
    return cost;
}

/* ─── Main ───────────────────────────────────────────────────────────────── */
int main(int argc, char *argv[])
{
    double t_init_start = MPI_Wtime();   /* MPI_Wtime works before Init too   */

    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    /* ── Parse args (all processes) ── */
    char *input_file = NULL;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-i") == 0 && i + 1 < argc)
            input_file = argv[++i];
        /* -p is accepted but we rely on mpirun -np for actual process count */
    }

    if (!input_file) {
        if (rank == 0)
            fprintf(stderr, "Usage: mpirun -np <P> %s -p <P> -i <input_file>\n", argv[0]);
        MPI_Finalize();
        return 1;
    }

    /* ── Rank 0 reads the file and broadcasts ── */
    if (rank == 0) {
        FILE *fp = fopen(input_file, "r");
        if (!fp) { perror("fopen"); MPI_Abort(MPI_COMM_WORLD, 1); }

        fscanf(fp, "%d", &N);
        memset(energy, 0, sizeof(energy));

        for (int j = 1; j < N; j++) {
            for (int i = 0; i < j; i++) {
                int val;
                fscanf(fp, "%d", &val);
                energy[i][j] = val;
                energy[j][i] = val;
            }
        }
        fclose(fp);
    }

    /* Broadcast problem size and matrix to all processes */
    MPI_Bcast(&N,      1,                    MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Bcast(energy,  MAX_CITIES*MAX_CITIES, MPI_INT, 0, MPI_COMM_WORLD);

    double t_init_end = gettime();
    double t_init = t_init_end - t_init_start;

    /* ─────────────────────────────────────────────────────────────────────
     * Parallelisation strategy:
     *   - The search tree is divided at the first level (first move from
     *     city 0). There are N-1 such sub-trees.
     *   - Sub-trees are distributed across ranks using static cyclic
     *     assignment: rank r handles first moves where
     *     (first_move - 1) % size == rank.
     *   - Each rank runs its own independent B&B with a LOCAL best bound.
     *   - After all local work is done, MPI_Reduce collects the global
     *     minimum cost (MPI_MIN), then the rank holding it broadcasts the
     *     full path.
     *   - This avoids expensive mid-computation all-to-all communication
     *     while still exploiting parallelism.
     * ───────────────────────────────────────────────────────────────────── */

    /* Initialise local best with greedy bound so pruning starts tight */
    local_best_cost = greedy_bound();
    memset(local_best_path, -1, sizeof(local_best_path));

    double t_comp_start = gettime();

    /* Each rank processes its assigned first-move sub-trees */
    for (int first_move = 1; first_move < N; first_move++) {

        /* Static cyclic distribution */
        if ((first_move - 1) % size != rank) continue;

        int path[MAX_CITIES];
        int visited[MAX_CITIES];
        memset(visited, 0, sizeof(visited));

        path[0] = 0;
        visited[0] = 1;
        path[1] = first_move;
        visited[first_move] = 1;

        int cost = energy[0][first_move];
        if (cost < local_best_cost)
            branch_and_bound(path, 2, visited, cost);
    }

    double t_comp_end = gettime();
    double t_comp_local = t_comp_end - t_comp_start;

    /* ── Gather global best cost via reduction ── */
    /* Pack cost+rank into a struct for MPI_MINLOC */
    struct { int cost; int rank; } local_pair, global_pair;
    local_pair.cost = local_best_cost;
    local_pair.rank = rank;

    MPI_Reduce(&local_pair, &global_pair, 1, MPI_2INT, MPI_MINLOC,
               0, MPI_COMM_WORLD);

    /* The rank that holds the global minimum broadcasts its path */
    int winning_rank = 0;
    if (rank == 0) winning_rank = global_pair.rank;
    MPI_Bcast(&winning_rank, 1, MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Bcast(local_best_path, MAX_CITIES, MPI_INT, winning_rank, MPI_COMM_WORLD);

    /* Collect the max computation time across all ranks (wall-clock) */
    double t_comp_max;
    MPI_Reduce(&t_comp_local, &t_comp_max, 1, MPI_DOUBLE, MPI_MAX,
               0, MPI_COMM_WORLD);

    /* ── Output (rank 0 only) ── */
    if (rank == 0) {
        printf("\n=== Wariara Freights - MPI Branch-and-Bound ===\n");
        printf("Processes       : %d\n", size);
        printf("Cities          : %d\n", N);
        printf("Min Energy (kWh): %d\n", global_pair.cost);
        printf("Optimal Route   : ");
        for (int i = 0; i < N; i++)
            printf("%d%s", local_best_path[i] + 1, (i < N - 1) ? " -> " : "\n");

        printf("\n--- Timing ---\n");
        printf("Init Time  (Tinit) : %.6f s\n", t_init);
        printf("Comp Time  (Tcomp) : %.6f s\n", t_comp_max);
        printf("Total Time         : %.6f s\n", t_init + t_comp_max);
    }

    MPI_Finalize();
    return 0;
}
