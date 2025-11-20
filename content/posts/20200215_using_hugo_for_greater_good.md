---
title: "Setting up a personal website using Hugo"
date: "2020-02-15"
draft: false
categories: ["Development","Hugo"]
tags:
keywords: ["Hugo"]
markup: "goldmark"
katex: "true"
---

As many before me, I've decided I need a website to share some of my work and ideas in an uncensored fashion. I set up this page almost a year ago, but I didn't add any content in the meanwhile. This was in part simply due to lack of motivation and second due to focusing on other projects (I'm saving some of these for blog posts).

Getting back to the website was easier this time round. Still I have decided to document the process of creating the website, so I can come back to it easily at any future point (hopefully sooner than one year).

Since this post is aimed mostly towards myself, I might come back and add further instructions as I move along.

## Installing Hugo

To install Hugo on Linux I followed the instructions [here](https://gohugo.io/getting-started/installing/#install-hugo-from-tarball) under the section "Install Hugo from Tarball". Releases can be found at https://github.com/gohugoio/hugo/releases.

After downloading the right tarball, I used the following commands to verify wasn't corrupted during the download, and install Hugo into my local `bin` directory:
```
tar tvf hugo_0.55.6_Linux-64bit.tar.gz
cd ~/.local/bin
tar -xvzf ~/Downloads/hugo_0.55.6_Linux-64bit.tar.gz
```
To check installation was succesful I ran the command
```
$ hugo version
Hugo Static Site Generator v0.55.6-A5D4C82D linux/amd64 BuildDate: 2019-05-18T07:56:30Z
```

The [Getting Started](https://gohugo.io/categories/getting-started) from Hugo contains tons of helpful information to move forward.

## Adding blog posts

To add a blog post just create a content file `/content/posts/<FILE>.<FORMAT>` and provide the needed metadata and post content. The metadata is stored in the [front matter](https://gohugo.io/content-management/front-matter/) of a post using either YAML (identified by opening and closing `+++`), TOML (identified by opening or closing `---`) or JSON (a single JSON object surrounded by curly braces `{` and `}`, followed by a new line).

The command
```bash
hugo new posts/my-latest-post.md
```
can be used to create a new content file and automatically set the date and title. The command will guess the type file of to create based on the path provided. The command should be run within the root directory of the site.

[Archetype](https://gohugo.io/content-management/archetypes/) templates can be used to preconfigure the front matter and possibly also the content dispositions for the the different content types.

## Deploying the page

### Host on GitHub

At the moment I am hosting this website using GitHub pages as a user page located at https://ivan-pi.github.io. The sources are located at https://github.com/ivan-pi/hugo_blog. This kind of setup is described in the [Hugo](https://gohugo.io/hosting-and-deployment/hosting-on-github/) documentation.

Deploying the page is automated using the `deploy.sh` script:
```
./deploy.sh [message]
```
which accepts an optional commit message. The page should be up and running within a couple minutes.

## Displaying math using Katex

### Latex

Math can be rendered using the [Katex](https://katex.org/) engine. The necessary lines of HTML to achieve this are found in the partials folder `\themes\mytheme\layouts\partials\` in the file `katex.html`.

To use math in a post it is necessary to set the following two page variables:
```
markup: "mmark"
katex: "true"
```

Consult the [Supported Functions](https://katex.org/docs/supported.html) page to make sure if a TeX function is supported or not.

---

Warning: mmark will be deprecated in the future, so a different solution will be needed.

---

### Equation numbering

A numbered equation shortcode has been added to simple Hugo theme in `themes/simple-hugo-theme/layouts/shortcodes/neq.html` and can be called as follows:
```
{{</* neq 1 "E=mc^2"  */>}}
```
where the first argument is the displayed equation number, and the second argument is a valid KaTeX formula (enclosed between quotation marks).

Sample output:

{{< neq 1 "E=mc^2"  >}}

At the moment referencing must be performed manually. If you find of a better solution for equation numbering, please let me know.

Related:
* [KaTeX \tag hack](https://jsfiddle.net/p9du5Lgq/5/?utm_source=website&utm_medium=embed&utm_campaign=p9du5Lgq)
* [Equation numbering (KaTeX issue)](https://github.com/KaTeX/KaTeX/issues/350)

