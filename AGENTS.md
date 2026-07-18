# AGENTS.md

Guidance for AI agents working in this repository. Humans: the full handbook is
[`instructions_for_myself.md`](instructions_for_myself.md).

## What this is

Ivan Pribec's personal blog — the **Hugo** sources for <https://ivan-pi.github.io>.
Work here is mostly **writing and editing Markdown** under `content/`. Only the
sources live here; the rendered HTML is deployed to a *separate* repo.

- Static site generator: **Hugo**, non-extended, **≥ 0.146.0**
- Theme: `hugo-simple`, vendored as a git submodule in `themes/hugo-simple`
- Config: `config.toml` · Content: `content/` · Theme overrides: `layouts/`

## Building & testing

Hugo and the theme submodule are installed automatically at the start of each
web session by `.claude/hooks/session-start.sh`. A clean `hugo` build **is** the
test for this repo — run it after any change to content, config, layouts, or the
theme:

```bash
hugo            # build; must finish with no errors
hugo server -D  # local preview incl. drafts → http://localhost:1313
```

## Content rules

- **Every file in `content/posts/` must begin with front matter containing at
  least `title` and `date`.** Without it, Hugo renders a broken `0001-01-01`
  entry with no title. New-post template:

  ```markdown
  ---
  title: "A Clear, Human Title"
  date: 2026-07-18
  draft: true            # flip to false to publish
  tags: ["Fortran"]      # optional
  ---
  ```
- Filename convention: `content/posts/YYYYMMDD_short-slug.md`. The date prefix is
  only for sorting — the URL comes from the post's `date` + `title`.
- Keep unfinished work as `draft: true`.
- Math is KaTeX (`$…$`, `$$…$$`); numbered equations use the `{{< neq >}}`
  shortcode. **Do not delete `layouts/_shortcodes/neq.html`** — several posts
  need it and the build fails without it.

## Do not

- **Do not run `./deploy.sh`** or push to the published site. Deployment is the
  owner's job; the script force-pushes the rendered site to the live GitHub Pages
  repo.
- **Do not commit build output** (`public/`, `resources/_gen/`,
  `.hugo_build.lock`) — all gitignored.
- **Do not edit files under `themes/`** — customise via `layouts/`, which
  overrides the theme and survives theme updates.

For anything else — deployment, KaTeX details, shortcodes, troubleshooting — see
[`instructions_for_myself.md`](instructions_for_myself.md).
