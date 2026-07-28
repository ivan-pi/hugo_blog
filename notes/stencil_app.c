#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef double FLOAT;

typedef struct {
    const FLOAT *data;
    int nx;
    int ny;
    int stride;
} Field;

// Define a function pointer type for our kernels
typedef void (*stencil_kernel_t)(
    const FLOAT * restrict, 
    FLOAT * restrict,
    const int,
    const FLOAT,
    const FLOAT,
    const int, const int, 
    const int, const int);

// ============================================================================
// Kernel A: Pointer Temporaries
// ============================================================================
static void iterate0_kernel(
    const FLOAT * restrict readField, 
    FLOAT * restrict writeField,
    const int nx,
    const FLOAT X,
    const FLOAT Y,
    const int xstart, const int xend, 
    const int ystart, const int yend)
{
    const int stride = nx + 2;

    const FLOAT * restrict readPtr_S = readField + (ystart - 1) * stride;
    const FLOAT * restrict readPtr_W = readField + (ystart    ) * stride - 1;
    const FLOAT * restrict readPtr_E = readField + (ystart    ) * stride + 1;
    const FLOAT * restrict readPtr_N = readField + (ystart + 1) * stride;
    FLOAT * restrict writePtr        = writeField + ystart * stride;

#pragma omp parallel for default(none) \
    shared(readPtr_S, readPtr_W, readPtr_E, readPtr_N, writePtr) \
    firstprivate(nx, X, Y, xstart, xend, ystart, yend, stride)
    for (int y = ystart; y < yend; y++) {
#pragma GCC ivdep
        for (int x = xstart; x < xend; x++) {
            writePtr[x] = X * (readPtr_W[x] + readPtr_E[x]) +
                          Y * (readPtr_S[x] + readPtr_N[x]);
        }
        readPtr_S += stride;
        readPtr_W += stride;
        readPtr_E += stride;
        readPtr_N += stride;
        writePtr  += stride;
    }
}

// ============================================================================
// Kernel B: Direct 2D Linear Indexing
// ============================================================================
static void iterate0_kernel_indexed(
    const FLOAT readField[restrict], 
    FLOAT writeField[restrict],
    const int nx,
    const FLOAT X,
    const FLOAT Y,
    const int xstart, const int xend, 
    const int ystart, const int yend)
{
    const int stride = nx + 2;
    #define IDX(y, x) ((y) * stride + (x))

#pragma omp parallel for default(none) \
    shared(readField, writeField) \
    firstprivate(nx, X, Y, xstart, xend, ystart, yend, stride)
    for (int y = ystart; y < yend; y++) {
#pragma GCC ivdep
        for (int x = xstart; x < xend; x++) {
            writeField[IDX(y, x)] = 
                X * (readField[IDX(y, x - 1)] + readField[IDX(y, x + 1)]) +
                Y * (readField[IDX(y - 1, x)] + readField[IDX(y + 1, x)]);
        }
    }
    #undef IDX
}

// ============================================================================
// Timing utility
// ============================================================================
static double walltime() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1.0e-9;
}

// ============================================================================
// Gnuplot Output Writer
// ============================================================================
static void write_gnuplot(Field desc, const char *filename) {
    FILE *fp = stdout; // Default to standard output stream

    if (filename != NULL) {
        fp = fopen(filename, "w");
        if (!fp) {
            fprintf(stderr, "Failed to open %s for writing. Falling back to stdout.\n", filename);
            fp = stdout;
        }
    }

    // Gnuplot 'splot' expects a blank line between differing Y rows for grid surfaces
    for (int y = 0; y <= desc.ny + 1; y++) {
        for (int x = 0; x <= desc.nx + 1; x++) {
            FLOAT val = desc.data[y * desc.stride + x];
            fprintf(fp, "%d %d %g\n", x, y, (double)val);
        }
        fprintf(fp, "\n");
    }

    // Only close the file and print confirmation if we actually opened a file on disk
    if (fp != stdout) {
        fclose(fp);
        printf("Field data written to: %s\n", filename);
    }
}

// ============================================================================
// Main Program
// ============================================================================
int main(int argc, char *argv[]) {
    if (argc < 5) {
        fprintf(stderr, "Usage: %s -k <A|B> <nx> <ny> <nsteps>\n", argv[0]);
        fprintf(stderr, "  -k A   : Use Kernel A (pointer temporaries)\n");
        fprintf(stderr, "  -k B   : Use Kernel B (direct 2D indexing)\n");
        return EXIT_FAILURE;
    }

    char kernel_choice = 'A';
    int nx = 0, ny = 0, nsteps = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-k") == 0 && i + 1 < argc) {
            kernel_choice = argv[i+1][0];
            i++;
        } else if (nx == 0) {
            nx = atoi(argv[i]);
        } else if (ny == 0) {
            ny = atoi(argv[i]);
        } else if (nsteps == 0) {
            nsteps = atoi(argv[i]);
        }
    }

    if (kernel_choice != 'A' && kernel_choice != 'B') {
        fprintf(stderr, "Invalid kernel choice. Use A or B.\n");
        return EXIT_FAILURE;
    }

    // Set the function pointer based on user choice
    stencil_kernel_t kernel = (kernel_choice == 'A') ? iterate0_kernel : iterate0_kernel_indexed;

    // Allocate memory with ghost cells (1 padding on each side for X and Y)
    const int stride = nx + 2;
    const int total_size = stride * (ny + 2);
    size_t bytes = (size_t)total_size * sizeof(FLOAT);

    FLOAT *field1 = (FLOAT *)malloc(bytes);
    FLOAT *field2 = (FLOAT *)malloc(bytes);

    if (!field1 || !field2) {
        fprintf(stderr, "Failed to allocate memory for %d x %d grids\n", nx, ny);
        return EXIT_FAILURE;
    }

    memset(field1, 0, bytes);
    memset(field2, 0, bytes);
    
    // Set a hot wall on the left boundary
    for (int y = 0; y < ny + 2; y++) {
        field1[y * stride + 0] = 1.0;
        field2[y * stride + 0] = 1.0;
    }

    const FLOAT X = 0.25;
    const FLOAT Y = 0.25;

    const int xstart = 1;
    const int xend   = nx + 1;
    const int ystart = 1;
    const int yend   = ny + 1;

    FLOAT *readField = field1;
    FLOAT *writeField = field2;

    printf("Running Kernel %c on a %d x %d grid for %d steps...\n", kernel_choice, nx, ny, nsteps);

    // Warm-up iteration (not timed)
    kernel(readField, writeField, nx, X, Y, xstart, xend, ystart, yend);

    // Main timing loop
    double start_time = walltime();

    for (int step = 0; step < nsteps; step++) {
        // Execute the chosen kernel via function pointer
        kernel(readField, writeField, nx, X, Y, xstart, xend, ystart, yend);
        
        // Swap pointers
        FLOAT *temp = readField;
        readField = writeField;
        writeField = temp;
    }

    double end_time = walltime();
    double elapsed = end_time - start_time;

    // Compute Metrics using size_t to prevent overflow on large grids/steps
    size_t points_per_step = (size_t)nx * (size_t)ny;
    size_t total_point_updates = points_per_step * (size_t)nsteps;
    double pups = (double)total_point_updates / elapsed;

    // Effective Bandwidth: 1 Read and 1 Write per grid point
    size_t total_bytes_moved = total_point_updates * 2 * sizeof(FLOAT);
    double bandwidth_GBs = (double)total_bytes_moved / elapsed / 1.0e9;

    printf("======================================\n");
    printf("Elapsed Time : %.4f seconds\n", elapsed);
    printf("Updates/sec  : %.2e (PUPS)\n", pups);
    printf("Bandwidth    : %.2f GB/s\n", bandwidth_GBs);
    printf("======================================\n");

    // Output final field. Pass a string to write to file, or pass NULL to print to stdout.
    write_gnuplot((Field){
        .data = readField,
        .nx = nx,
        .ny = ny,
        .stride = stride
    }, "field_output.dat");

    free(field1);
    free(field2);

    return EXIT_SUCCESS;
}
