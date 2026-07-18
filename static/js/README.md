# Vendored: `gnuplot_svg.js`

`gnuplot_svg.js` is **third-party code, vendored unmodified** — it is not
authored in this repository and must not be edited here.

- **What it is:** gnuplot's mouse/keyboard interaction library for SVG plots
  produced with `set terminal svg ... mouse jsdir '/js'`. It provides the
  hover coordinate read-out, legend click-to-toggle, pan/zoom, and grid
  toggle for the interactive figures on the blog.
- **Where it comes from:** a byte-identical copy of
  `/usr/share/gnuplot/gnuplot/6.0/js/gnuplot_svg.js` from **gnuplot 6.0**
  (Ubuntu package `gnuplot`); in the gnuplot source tree the file lives at
  `term/js/gnuplot_svg.js`. The gnuplot project is hosted on SourceForge
  (<http://gnuplot.sourceforge.net/>), where this plugin originates: it was
  contributed to gnuplot by **Marko Karjalainen** (see the attribution
  header inside the file) and has been maintained by the gnuplot project
  since.
- **License:** distributed under the gnuplot license (Copyright Thomas
  Williams, Colin Kelley and contributors), which permits copying and
  distribution of unmodified files provided the copyright and permission
  notice is retained — see the `Copyright` file of the gnuplot
  distribution. The license restricts distribution of *modified* source,
  which is one more reason this copy must stay byte-identical.
- **Updating:** if the interactive SVGs are regenerated with a newer
  gnuplot, replace this file with the copy shipped by that same release
  (and update the version references above).
