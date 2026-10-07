# nvh-markdown

Markdown for [Novus](https://github.com/ezTxmMC/novus) and nvh: a Markdown renderer written in
Novus, a few nvh components, and the generator for `.nvmd` files - Markdown with Novus in it,
the way `.mdx` is Markdown with JSX. The generator turns `Page.nvmd` into `Page.nvh`; the compiler
itself knows nothing about `.nvmd`.

## Installation

In the `project.nv` of your project:

```
require "github.com/ezTxmMC/nvh-markdown" "latest"
replace "github.com/ezTxmMC/nvh-markdown" "../nvh-markdown"     // a local checkout, optional
```

```nv
import "github.com/ezTxmMC/nvh-markdown/markdown"       // markdown.render(...)
import "github.com/ezTxmMC/nvh-markdown/components"     // Callout, CodeBlock, Toc, Markdown
```

A project with `.nvmd` files needs the `require` and the generator (below); the generated `.nvh` imports the
`markdown` package itself.

## The `markdown` package

```
markdown.render(string source): string                     Markdown -> HTML
markdown.fill(string html, array values): string           markers of .nvmd -> escaped values
markdown.frontmatter(string source): map<string, string>   the `key: value` pairs between the --- lines
markdown.body(string source): string                       the source without its frontmatter
markdown.headings(string source): array<Heading>           level, id, text of every heading
markdown.slug(string text): string                         "Hello, World!" -> "hello-world"
markdown.highlight(string language, string code): string   HTML with <span class="tok-...">
markdown.text(string source): string                       plain text, for a search index
```

`Heading` has the fields `level` (1-6), `id` and `text`; `id` is what `render` writes into the
heading (duplicates get `-1`, `-2`, ...), so `headings` and `render` always agree.
A heading that is only `{expr}` has no text to take the id from: name it with a trailing `{#id}`
(`# {title} {#intro}`; `[A-Za-z0-9_-]`), which works in plain Markdown too.

### Dialect

CommonMark core (ATX and setext headings, paragraphs, emphasis, code spans, fenced and indented
code, block quotes, nested lists, links, images, reference links, autolinks, hard breaks, HTML
blocks and inline HTML) plus GFM tables with alignment, task lists, `~~strikethrough~~` and bare
`http(s)://` links, plus containers:

```
:::note Optional title
text, **Markdown**
:::
```

(`note`, `tip`, `warning`, `danger`). Raw HTML is passed through for the usual tags;
`<script>`, `<style>` and unknown tags are shown as text, and `javascript:` links become `#`.

The output is plain semantic HTML with stable class names, so any CSS - Tailwind included - can
style it: `heading-anchor`, `code-block` (with `data-language`), `callout callout-<kind>`,
`callout-title`, `table-wrapper`, `task-list-item`, and for highlighted code `tok-kw`, `tok-str`,
`tok-num`, `tok-com`, `tok-fn`, `tok-type`, `tok-op`, `tok-punct`. Languages: `nv`, `nvh`/`html`,
`sh`, `json`, `c`, `js`/`ts`, `toml`, `yaml`; any other language is only escaped.

## Components

`components/` holds nvh components without any styling of their own:

| Component | Props | |
|---|---|---|
| `Callout` | `type` (`note`), `title` | `<aside class="callout callout-{type}">` around its slot |
| `CodeBlock` | `code`, `language` | a highlighted `<pre class="code-block">` |
| `Toc` | `headings`, `minLevel` (2), `maxLevel` (3) | a `<nav class="toc">` list of anchors |
| `Markdown` | `source` | renders Markdown at run time |

## `.nvmd`

`Page.nvmd` is a component like `Page.nvh`: frontmatter keys become props, a `<?nv ... ?>` header
holds imports, props and methods, and the body is Markdown with `{expr}`, `{#if}`, `{#for}` and
`<Component>` tags. `novusc` reads `.nv` and `.nvh` only, so a generator writes the `.nvh` next to every
`.nvmd`; run it before the compiler:

```sh
novusc run nvh-markdown/nvmd.nv build content        # name.nvmd -> name.nvh, only what changed (--force: all)
novusc run nvh-markdown/nvmd.nv watch content        # rebuild while you write, Ctrl+C ends it
novusc run nvh-markdown/nvmd.nv translate Page.nvmd  # print the .nvh of one file
novusc run nvh-markdown/nvmd.nv clean content        # remove the generated files
novusc run nvh-markdown/nvmd.nv check content --main main.nv   # build, `novusc check`, errors name the .nvmd line
novusc run main.nv
```

Put `*.nvh` of the content folders into `.gitignore`: they are build output. A generated file starts with
`<?nv /* nvmd-generated */`; the generator never overwrites or removes a `.nvh` without that mark. The
generated file has the same lines as the source: an error of the compiler points at the right line of the
`.nvmd` (inside a Markdown segment at its first line). The same from a program:

```nv
import "github.com/ezTxmMC/nvh-markdown/nvmd"

nvmd.translate(source, "Page.nvmd"): string        // the .nvh text
nvmd.build(["content"], false): BuildReport        // written / unchanged lists
nvmd.watch(["content"])                            // blocks until Ctrl+C
nvmd.clean(["content"]): BuildReport
```

Two rules of the format worth knowing: a closing `?>` of a header stands on a line of its own (the generator
adds the `markdown` import in front of it), and an HTML block with a handler (`<button @click="hit">`,
`bind=`, `class:x={...}`) is nvh, not Markdown - it stays as written up to the next blank line. The full
format is in [NVMD_SPEC.md](NVMD_SPEC.md).

## Tests

```sh
test/run.sh              # golden tests (NOVUSC=path/to/novusc if novusc is not in PATH)
test/run.sh --update     # rewrite the golden files, review the diff
```

Layout: `nvmd/` is the translator (`translate`, `build`, `watch`), `nvmd.nv` its command line, `markdown/` is the API, `markdown/block` and `markdown/leaf` parse blocks,
`markdown/inline` the text inside them, `markdown/highlight` the code, `markdown/model` and
`markdown/escape` what they share.
