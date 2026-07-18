# rbf-fd-matrix-sizes.gp
#
# Storage size of the (dense) RBF-FD system matrix vs. polynomial order,
# using the "twice the number of polynomial terms" stencil-size heuristic.
# Generates content/images/rbf-fd-matrix-sizes.svg for the blog post
#   "Sizing RBF-FD Stencils for Modern CPU Caches".
#
# Run from the repository root:
#   gnuplot notes/rbf-fd-matrix-sizes.gp
#
# Model -----------------------------------------------------------------
#   # monomials of total degree < p    2-D: triangular   T(p)  = p(p+1)/2
#                                       3-D: tetrahedral  Te(p) = p(p+1)(p+2)/6
#   heuristic stencil size  n = 2 m  ->  augmented matrix is (n + m) = 3m square
#   storage = (3m)^2 * bytes / 1024   [KB],  bytes = 4 (fp32) or 8 (fp64)

m2(p)   = p*(p+1)/2.0
m3(p)   = p*(p+1)*(p+2)/6.0
dim(m)  = 3.0*m
kb(m,b) = (dim(m)**2 * b) / 1024.0

# defined only for polynomial order >= 1 (data starts at 1; the axis starts at 0)
f2_32(p) = (p >= 1) ? kb(m2(p),4) : NaN
f2_64(p) = (p >= 1) ? kb(m2(p),8) : NaN
f3_32(p) = (p >= 1) ? kb(m3(p),4) : NaN
f3_64(p) = (p >= 1) ? kb(m3(p),8) : NaN

# --- output selection (default: SVG for the blog) ----------------------
if (!exists("term")) term = "svg"
if (!exists("out"))  out  = "content/images/rbf-fd-matrix-sizes.svg"
if (term eq "svg") { set terminal svg size 840,560 font "Helvetica,13" background rgb "white" }
if (term eq "png") { set terminal pngcairo size 1008,672 font "Helvetica,13" background rgb "white" }
set output out

# --- styles ------------------------------------------------------------
set style line 1 lc rgb "#1f6fb4" lw 2.5 pt 7 ps 1.1 dt 1   # 2-D fp64  solid  filled circle
set style line 2 lc rgb "#1f6fb4" lw 2.5 pt 6 ps 1.1 dt 2   # 2-D fp32  dashed open   circle
set style line 3 lc rgb "#d7301f" lw 2.5 pt 5 ps 1.1 dt 1   # 3-D fp64  solid  filled square
set style line 4 lc rgb "#d7301f" lw 2.5 pt 4 ps 1.1 dt 2   # 3-D fp32  dashed open   square
set style line 9 lc rgb "#8a8a8a" lw 1.2 dt 3               # L1D cache reference lines

set border lc rgb "#444444"
set tics nomirror out
set grid ytics lc rgb "#e6e6e6" lw 1, lc rgb "#f2f2f2" lw 1
set mytics 10

set title "RBF-FD system-matrix size vs. polynomial order\n{/*0.72 dense (3m)×(3m) system per stencil,  stencil size n = 2·(number of polynomial terms)}" font ",15" tc rgb "#222222"
set xlabel "Polynomial order"
set ylabel "Matrix storage (KB)"

set xrange [0:15]
set xtics 1
set yrange [0.02:60000]
set logscale y
set format y "%g"

set samples 16          # evaluate curves exactly at integer polynomial orders 0..15
set key at graph 0.03, graph 0.97 left top reverse Left samplen 2.2 spacing 1.15 \
        font ",11" box lc rgb "#cccccc" opaque

# --- L1 data cache band + reference lines ------------------------------
# Each label is centred on its line; an opaque box masks the line behind the
# text. The 48 KB line is dropped so the labels are not crowded.
set style textbox opaque fillcolor rgb "white" noborder margins 0.5,0.4
set object 1 rectangle from graph 0, first 32 to graph 1, first 128 \
        fillcolor rgb "#000000" fillstyle transparent solid 0.05 noborder behind
set arrow 1 from graph 0, first 32  to graph 1, first 32  nohead ls 9 back
set arrow 3 from graph 0, first 64  to graph 1, first 64  nohead ls 9 back
set arrow 4 from graph 0, first 128 to graph 1, first 128 nohead ls 9 back

set label 11 "128 KB  Apple M (P-core)" at graph 0.98, first 128 right boxed font ",10" tc rgb "#555555" front
set label 12 "64 KB  Grace, A64FX"      at graph 0.98, first 64  right boxed font ",10" tc rgb "#555555" front
set label 14 "32 KB  Zen 4"             at graph 0.98, first 32  right boxed font ",10" tc rgb "#555555" front
set label 15 "L1 data cache" at graph 0.02, first 90 left font ",10" tc rgb "#777777" front

# --- plot --------------------------------------------------------------
plot f2_64(x) w linespoints ls 1 title "2-D, fp64", \
     f2_32(x) w linespoints ls 2 title "2-D, fp32", \
     f3_64(x) w linespoints ls 3 title "3-D, fp64", \
     f3_32(x) w linespoints ls 4 title "3-D, fp32"
