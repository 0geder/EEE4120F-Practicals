// =========================================================================
// Practical 3: Minimum Energy Consumption Freight Route Optimization
// =========================================================================
//
// GROUP NUMBER:
//
// MEMBERS:
//   - Member 1 Samson Okuthe, OKTSAM001
//   - Member 2 Nyakallo Peete, PTXNYA001

// ========================================================================
//  PART 1: Minimum Energy Consumption Freight Route Optimization using OpenMP
// =========================================================================


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/time.h>
#include <omp.h>

#define MAX_N 10

// ============================================================================
// Global variables
// ============================================================================

int procs = 1;

int n;
int adj[MAX_N][MAX_N];

// ── Shared best solution (protected by best_lock) ──────────────────────────
int          best_cost;
int          best_path[MAX_N];
omp_lock_t   best_lock;

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
  printf("Usage: %s [options]\n", program);
  printf("-p <num>\tNumber of processors/threads to use\n");
  printf("-i <file>\tInput file name\n");
  printf("-o <file>\tOutput file name\n");
  printf("-h \t\tDisplay this help\n");
}

// ============================================================================
// Greedy nearest-neighbour heuristic — produces a good initial upper bound
// so the B&B pruning is tight from the very first node expansion.
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
// Recursive Branch-and-Bound
//
//   path[]       – cities visited so far (0-indexed)
//   depth        – number of cities in path so far
//   visited[]    – visited[i] = 1 means city i is already in the path
//   current_cost – cumulative energy cost of the partial route
//
// Parallelisation note:
//   Called from inside the OpenMP parallel for loop.
//   Each thread has its OWN private path[] and visited[] on the stack,
//   so there is NO race on those arrays.  The only shared state is
//   best_cost / best_path, which is protected by best_lock.
// ============================================================================

void branch_and_bound(int path[], int depth,
                      int visited[], int current_cost)
{
    /* ── Base case: all cities visited → check if this is a new best ── */
    if (depth == n) {
        omp_set_lock(&best_lock);
        if (current_cost < best_cost) {
            best_cost = current_cost;
            memcpy(best_path, path, n * sizeof(int));
        }
        omp_unset_lock(&best_lock);
        return;
    }

    int last = path[depth - 1];   /* last city added to the partial route */

    for (int next = 0; next < n; next++) {

        if (visited[next]) continue;   /* skip already-visited cities */

        int new_cost = current_cost + adj[last][next];

        /* ── Bound check: read global best and prune if no improvement ── */
        omp_set_lock(&best_lock);
        int bound = best_cost;
        omp_unset_lock(&best_lock);

        if (new_cost >= bound) continue;   /* prune this subtree */

        /* ── Branch: extend the path ── */
        visited[next] = 1;
        path[depth]   = next;

        branch_and_bound(path, depth + 1, visited, new_cost);

        /* ── Backtrack ── */
        visited[next] = 0;
    }
}


int main(int argc, char **argv)
{
    int opt;
    int i, j;
    char *input_file  = NULL;
    char *output_file = NULL;
    FILE *infile      = NULL;
    FILE *outfile     = NULL;
    int success_flag  = 1;   /* 1 = good, 0 = error/help encountered */

    /* ── Record start of initialisation ── */
    double t_init_start = gettime();

    while ((opt = getopt(argc, argv, "p:i:o:h")) != -1)
    {
        switch (opt)
        {
            case 'p':
            {
                procs = atoi(optarg);
                break;
            }

            case 'i':
            {
                input_file = optarg;
                break;
            }

            case 'o':
            {
                output_file = optarg;
                break;
            }

            case 'h':
            {
                Usage(argv[0]);
                success_flag = 0;
                break;
            }

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

    if (!success_flag) return 1;

    /* ── Apply thread count ── */
    omp_set_num_threads(procs);

    printf("Running with %d processes/threads on a graph with %d nodes\n",
           procs, n);

    /* ────────────────────────────────────────────────────────────────────
     * Initialise shared best-solution state
     * ──────────────────────────────────────────────────────────────────── */
    omp_init_lock(&best_lock);
    memset(best_path, -1, sizeof(best_path));

    /* Compute greedy upper bound to seed the B&B pruning */
    best_cost = greedy_bound(best_path);

    double t_init_end = gettime();
    double t_init     = t_init_end - t_init_start;

    /* ────────────────────────────────────────────────────────────────────
     * PARALLEL BRANCH-AND-BOUND
     *
     * Decomposition: fix the first move from the hub (city 0) to each
     * possible next city.  There are n-1 such sub-problems — one per
     * loop iteration.  These are distributed across threads using
     * OpenMP dynamic scheduling (chunk = 1) so that faster-pruning
     * threads immediately pick up new work (work stealing).
     *
     * Each thread maintains private path[] and visited[] arrays on its
     * own stack, so there is no data race on the search state.
     * The only shared write is to best_cost / best_path, guarded by
     * best_lock.
     * ──────────────────────────────────────────────────────────────────── */
    double t_comp_start = gettime();

    #pragma omp parallel for schedule(dynamic, 1) \
        default(none) shared(adj, n, best_cost, best_path, best_lock)
    for (int first_move = 1; first_move < n; first_move++) {

        /* Thread-private search state */
        int path[MAX_N];
        int visited[MAX_N];
        memset(visited, 0, sizeof(visited));

        path[0]             = 0;          /* always start at hub (city 0) */
        visited[0]          = 1;
        path[1]             = first_move;
        visited[first_move] = 1;

        int cost = adj[0][first_move];

        /* Top-level prune before recursing */
        omp_set_lock(&best_lock);
        int bound = best_cost;
        omp_unset_lock(&best_lock);

        if (cost < bound)
            branch_and_bound(path, 2, visited, cost);
    }

    double t_comp_end = gettime();
    double t_comp     = t_comp_end - t_comp_start;

    omp_destroy_lock(&best_lock);

    /* ────────────────────────────────────────────────────────────────────
     * Write results to output file
     * ──────────────────────────────────────────────────────────────────── */
    fprintf(outfile, "Minimum Energy Cost: %d kWh\n", best_cost);
    fprintf(outfile, "Optimal Route: ");
    for (int k = 0; k < n; k++)
        fprintf(outfile, "%d%s", best_path[k] + 1,
                (k < n - 1) ? " -> " : "\n");

    /* Also print to stdout for convenience */
    printf("\n--- Results ---\n");
    printf("Min Energy (kWh): %d\n", best_cost);
    printf("Optimal Route   : ");
    for (int k = 0; k < n; k++)
        printf("%d%s", best_path[k] + 1, (k < n - 1) ? " -> " : "\n");

    /* ────────────────────────────────────────────────────────────────────
     * Print timing
     * ──────────────────────────────────────────────────────────────────── */
    printf("\n--- Timing ---\n");
    printf("Init Time  (Tinit) : %.6f s\n", t_init);
    printf("Comp Time  (Tcomp) : %.6f s\n", t_comp);
    printf("Total Time         : %.6f s\n", t_init + t_comp);

    fclose(outfile);
    return 0;
}