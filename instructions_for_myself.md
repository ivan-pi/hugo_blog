## Installing Hugo

Follow the instructions [here](https://gohugo.io/getting-started/installing/#install-hugo-from-tarball)

```
tar tvf hugo_0.55.6_Linux-64bit.tar.gz 
cd ~/.local/bin
tar -xvzf ~/Downloads/hugo_0.55.6_Linux-64bit.tar.gz
./hugo version
```
Hugo should now be installed.

## Using Katex

Math is rendered using the Katex engine. The necessary lines are in the partial `katex.html`. Posts containing math should set the following two page variables:
```
markup: "mmark"
katex: "true"
```