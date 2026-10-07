# .nvmd - Markdown + Novus

A `.nvmd` file is Markdown with Novus in it, the way `.mdx` is Markdown with JSX.
Like a `.nvh` file it is a component: `Page.nvmd` becomes `define class Page based NvhComponent`
(see std/web.nv). `novusc` does not know the format: the generator in `nvmd/` (command line `nvmd.nv`)
translates every `.nvmd` into the `.nvh` next to it, and the nvh compiler takes it from there. The Markdown
itself is rendered by the `markdown` package of this dependency, at render time.

Project wiring (a project that has `.nvmd` files); then `novusc run nvh-markdown/nvmd.nv build <folder>` before
`novusc run main.nv`, see the README:

```
require "github.com/ezTxmMC/nvh-markdown" "latest"
replace "github.com/ezTxmMC/nvh-markdown" "../nvh-markdown"     // local checkout
```

## Anatomy of a file

```
---
title: Control flow
description: if, while and for
---
<?nv
import strings
prop integer level = 1
ref integer clicks = 0
method hit() { clicks = clicks + 1 }
?>

# {title}

Plain **Markdown**, `inline code` and a value: {strings.upper(title)} / {level + 1}.

{#if level > 0}
Shown when `level` is positive.
{:else}
Shown otherwise.
{/if}

{#for name, i in ["Ada", "Grace"]}
- {i}: {name}
{/for}

<Callout type="warning">
Children are **Markdown** as well.
</Callout>

<button @click="hit">Clicked {clicks} times</button>

```nv
println "braces { } in code are never interpolated"
```
```

1. **Frontmatter** (optional, must be the first line): `---`, `key: value` lines (a scalar;
   optional single or double quotes), `---`. Every key made of `[A-Za-z0-9_]` becomes
   `prop string key = "value"` of the component, so a parent can override it and `{key}` works.
   `markdown.frontmatter(source)` returns the same pairs at runtime.
2. **Header block** `<?nv ... ?>` (optional, directly after the frontmatter): exactly the header
   of a `.nvh` file - imports, `prop`/`ref`, methods, defines.
3. **Body**: Markdown (dialect below) with these Novus constructs:
   - `{expr}` inline anywhere in Markdown text: the HTML-escaped value of the Novus expression.
     `\{` and `\}` are literal braces. Braces inside fenced code and inline code spans are
     always literal.
   - Block constructs, alone on their line (indentation allowed), passed to the nvh compiler
     unchanged: `{#if c}`, `{:else if c}`, `{:else}`, `{/if}`, `{#for x in xs}`,
     `{#for x, i in xs}`, `{/for}`, `{@html expr}`, `<?nv statements ?>`.
     They split the Markdown into segments.
   - Components: a tag starting with an upper-case letter, with nvh attribute syntax
     (`prop={x}`, `@event="handler"`, `key={id}`): `<Name ...>` on its own line, children
     (Markdown), `</Name>` on its own line; or self closing `<Name ... />`. Resolved like in
     `.nvh` (next to the file, in `components/`, in `../components/`).
   - Lower-case HTML tags are raw HTML and go through the Markdown renderer untouched
     (HTML blocks and inline HTML). `{expr}` works inside them as well.
4. Everything else is Markdown.

## Translation (what `nvmd/` generates)

Each Markdown segment (the text between two block constructs) becomes one nvh expression:

```
{@html markdown.render("<segment>")}                                    // no inline {expr}
{@html markdown.fill(markdown.render("<segment>"), [expr0, expr1])}     // with inline {expr}
```

Inline `{expr_i}` is replaced in the segment text by the marker `MARK_OPEN + i + MARK_CLOSE`
(`chr(1)`, the decimal index, `chr(2)`) before it is rendered. `markdown.render` passes the
two control characters and the digits between them through untouched wherever they stand (also
inside link text, emphasis, table cells, headings, raw HTML attributes). `markdown.fill(html,
values)` replaces every marker `i` by `web.text(values[i])` (HTML-escaped text of the value).
Markers never appear in a code span or fence (braces are literal there).

Segments are dedented by their common leading whitespace, so Markdown inside an indented
`{#if}` is not accidentally a code block.

**Header.** The generated file has exactly the lines of the source. The frontmatter and the user's
`<?nv ?>` header are merged into one header block: the frontmatter fence lines become `<?nv /* nvmd-generated */`
and the `prop` lines, the import `import "github.com/ezTxmMC/nvh-markdown/markdown"` goes in front of the
`?>` that closes the block. That `?>` stands on a line of its own (statements end at a line break). Without
frontmatter and header the first line gets `<?nv /* nvmd-generated */ import "..." ?>` in front of it.
The comment `/* nvmd-generated */` is the mark of a generated file: the generator only overwrites or removes
files that start with `<?nv /* nvmd-generated */`.

**HTML with handlers.** A block that starts with a lower-case tag and contains an event attribute (`@click=`,
`@keydown.enter=`), `bind=` or `class:name` runs to the next blank line and is passed through as nvh, not
rendered as Markdown. Everything else in lower-case HTML goes through the renderer.

**Errors.** Translation errors (`unclosed '{'`, `empty {}`, an unclosed frontmatter or header, a component
tag that shares its line with other text) are printed as `error: file:line: message` and end the program
with exit code 1. Errors of the nvh/Novus compiler point at a line of the generated file, which is the
same line of the source; inside a Markdown segment they point at the first line of that segment.

## Markdown dialect (`markdown.render`)

CommonMark core plus: GFM tables (with alignment), task lists, `~~strikethrough~~`, autolinks,
fenced code blocks with a language (` ```nv `) and syntax highlighting (`markdown.highlight`),
heading ids (`markdown.slug`, or an explicit trailing `{#id}`) with an anchor link, hard line breaks, reference links,
footnote-free. Containers:

```
:::note Optional title
text, **Markdown**
:::
```
for `note`, `tip`, `warning`, `danger` -> `<aside class="callout callout-note">...`.
Output is plain semantic HTML with stable class names (`callout`, `code-block`, `tok-kw`,
`tok-str`, ...) so any CSS - Tailwind included - can style it.
Raw text is HTML-escaped; raw HTML is passed through only for the usual block and inline tags.

## Runtime API of the package `markdown`

```
markdown.render(string source): string             Markdown -> HTML
markdown.fill(string html, array values): string   markers -> escaped values
markdown.frontmatter(string source): map<string, string>
markdown.body(string source): string               the source without its frontmatter
markdown.headings(string source): array<Heading>   level, id, text (for a table of contents)
markdown.slug(string text): string
markdown.highlight(string language, string code): string   HTML with <span class="tok-...">
markdown.text(string source): string               plain text (for a search index)
```
