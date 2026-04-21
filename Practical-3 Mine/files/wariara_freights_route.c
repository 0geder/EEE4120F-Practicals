/*
 * EEE4120F Practical 3 - Task 1: OpenMP Branch-and-Bound
 * Wariara Freights Inc. - Minimum Energy Route Solver (Shared Memory)
 *
 * Compile: gcc -O2 -fopenmp wariara_freights_route.c -o wariara_freights_route
 * Run:     ./wariara_freights_route -p <num_threads> -i <input_file>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <omp.h>

/* ─── Timing ─────────────────────────────────────────────────────────────── */
static double gettime(void) { return omp_get_wtime(); }

/* ─── Globals ─────────────────────────────────────────────────────────────── */
#define MAX_CITIES 20

int   N;                          /* number of client locations              */
int   energy[MAX_CITIES][MAX_CITIES]; /* energy cost matrix (0-indexed)      */

/* Shared best-solution state – protected by a lock */
int          best_cost;
int          best_path[MAX_CITIES];
omp_lock_t   best_lock;

/* ─── Recursive Branch-and-Bound ─────────────────────────────────────────── */
/*
 * branch_and_bound()
 *   path[]      – cities visited so far (0-indexed city numbers)
 *   depth       – how many cities are in path so far
 *   visited[]   – boolean array, visited[i]=1 means city i is in path
 *   current_cost– cumulative energy cost of path so far
 */
void branch_and_bound(int path[], int depth, int visited[], int current_cost)
{
    /* ── Leaf: all cities visited ── */
    if (depth == N) {
        /* Atomically update the global best */
        omp_set_lock(&best_lock);
        if (current_cost < best_cost) {
            best_cost = current_cost;
            memcpy(best_path, path, N * sizeof(int));
        }
        omp_unset_lock(&best_lock);
        return;
    }

    int last = path[depth - 1];   /* last city in current partial path */

    for (int next = 0; next < N; next++) {
        if (visited[next]) continue;

        int new_cost = current_cost + energy[last][next];

        /* ── Bound: prune if already worse than best known ── */
        omp_set_lock(&best_lock);
        int bound = best_cost;
        omp_unset_lock(&best_lock);

        if (new_cost >= bound) continue;   /* prune */

        /* ── Branch ── */
        visited[next] = 1;
        path[depth]   = next;

        branch_and_bound(path, depth + 1, visited, new_cost);

        visited[next] = 0;
    }
}

/* ─── Main ───────────────────────────────────────────────────────────────── */
int main(int argc, char *argv[])
{
    double t_init_start = gettime();

    /* ── Parse command-line arguments ── */
    int   num_threads = 1;
    char *input_file  = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-p") == 0 && i + 1 < argc)
            num_threads = atoi(argv[++i]);
        else if (strcmp(argv[i], "-i") == 0 && i + 1 < argc)
            input_file = argv[++i];
    }

    if (!input_file) {
        fprintf(stderr, "Usage: %s -p <threads> -i <input_file>\n", argv[0]);
        return 1;
    }

    omp_set_num_threads(num_threads);

    /* ── Read input file ── */
    FILE *fp = fopen(input_file, "r");
    if (!fp) { perror("fopen"); return 1; }

    fscanf(fp, "%d", &N);

    /* Initialise matrix to 0 */
    memset(energy, 0, sizeof(energy));

    /*
     * Input format (upper triangle, row by row):
     *   E[1][2]
     *   E[1][3] E[2][3]
     *   ...
     * We store 0-indexed: energy[i][j] = energy[j][i]
     */
    for (int j = 1; j < N; j++) {          /* column city (1-indexed) */
        for (int i = 0; i < j; i++) {      /* row city (0-indexed)    */
            int val;
            fscanf(fp, "%d", &val);
            energy[i][j] = val;
            energy[j][i] = val;
        }
    }
    fclose(fp);

    double t_init_end = gettime();
    double t_init = t_init_end - t_init_start;

    /* ── Initialise best solution ── */
    best_cost = INT_MAX;
    memset(best_path, -1, sizeof(best_path));
    omp_init_lock(&best_lock);

    /* ── Compute initial bound: greedy nearest-neighbour from city 0 ── */
    {
        int vis[MAX_CITIES] = {0};
        int cur = 0, cost = 0;
        vis[cur] = 1;
        best_path[0] = 0;
        for (int step = 1; step < N; step++) {
            int best_next = -1, best_e = INT_MAX;
            for (int k = 0; k < N; k++) {
                if (!vis[k] && energy[cur][k] < best_e) {
                    best_e = energy[cur][k];
                    best_next = k;
                }
            }
            vis[best_next] = 1;
            best_path[step] = best_next;
            cost += best_e;
            cur = best_next;
        }
        best_cost = cost;
    }

    /* ─────────────────────────────────────────────────────────────────────
     * Parallelisation strategy:
     *   - Fix the first move from city 0 to each possible second city.
     *   - Each of these N-1 sub-problems is an independent unit of work.
     *   - Distribute these sub-problems across threads with dynamic
     *     scheduling (work stealing) to handle imbalanced pruning.
     *   - Each thread has its own private path[] and visited[] stack.
     *   - The shared best_cost and best_path are protected by best_lock.
     * ───────────────────────────────────────────────────────────────────── */

    double t_comp_start = gettime();

    #pragma omp parallel for schedule(dynamic, 1) default(none) \
        shared(energy, N, best_cost, best_path, best_lock)
    for (int first_move = 1; first_move < N; first_move++) {

        int path[MAX_CITIES];
        int visited[MAX_CITIES];
        memset(visited, 0, sizeof(visited));

        path[0] = 0;              /* always start at city 0 (hub) */
        visited[0] = 1;

        path[1] = first_move;
        visited[first_move] = 1;

        int cost = energy[0][first_move];

        /* Prune at the top level too */
        omp_set_lock(&best_lock);
        int bound = best_cost;
        omp_unset_lock(&best_lock);

        if (cost < bound)
            branch_and_bound(path, 2, visited, cost);
    }

    double t_comp_end = gettime();
    double t_comp = t_comp_end - t_comp_start;

    omp_destroy_lock(&best_lock);

    /* ── Output ── */
    printf("\n=== Wariara Freights - OpenMP Branch-and-Bound ===\n");
    printf("Threads         : %d\n", num_threads);
    printf("Cities          : %d\n", N);
    printf("Min Energy (kWh): %d\n", best_cost);
    printf("Optimal Route   : ");
    for (int i = 0; i < N; i++)
        printf("%d%s", best_path[i] + 1, (i < N - 1) ? " -> " : "\n");

    printf("\n--- Timing ---\n");
    printf("Init Time  (Tinit) : %.6f s\n", t_init);
    printf("Comp Time  (Tcomp) : %.6f s\n", t_comp);
    printf("Total Time         : %.6f s\n", t_init + t_comp);

    return 0;
}
