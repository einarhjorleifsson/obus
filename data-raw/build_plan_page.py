#!/usr/bin/env python3
"""Render PLAN-qc-checks.md as a styled standalone page.

    python3 data-raw/build_plan_page.py [out.html]     # from the repo root

Needs `pandoc` on PATH. The markdown is the source of truth -- this converts it
rather than duplicating it, so the page cannot drift from the committed plan.

The rendered page is published as a private Claude artifact at
https://claude.ai/code/artifact/081c8ea1-9fae-46ee-921c-65b65b3fcb95
Republishing the same file path updates that URL in place.

What it adds over plain pandoc, all of it driven by the document's own content:

  * a sticky index built from pandoc's heading ids (NB the `\\s+` in the nav
    regex -- pandoc wraps a heading tag onto a second line when the generated id
    is long, and a literal space there silently drops those sections);
  * ICES's real WKDATR13 cell fills as swatches beside the verdict names in
    section 3.2, so the colour that encodes the verdict in the source report
    also encodes it here;
  * `[opus]` / `[obus]` rendered as ownership tags;
  * tables and pseudocode in their own horizontal scroll containers, so the
    page body never scrolls sideways;
  * a four-figure strip of the measurements the plan rests on.
"""
import re, subprocess, html, sys

SRC = "PLAN-qc-checks.md"
OUT = sys.argv[1] if len(sys.argv) > 1 else "PLAN-qc-checks.html"


body = subprocess.run(["pandoc", SRC, "-f", "gfm", "-t", "html",
                       "--no-highlight"],
                      capture_output=True, text=True, check=True).stdout

# drop the markdown H1 and the leading front-matter paragraphs: the page has
# its own masthead built from them
body = re.sub(r"<h1[^>]*>.*?</h1>\s*", "", body, count=1, flags=re.S)
paras = re.findall(r"<p>.*?</p>", body, flags=re.S)
lede = paras[:2]
for p in lede:
    body = body.replace(p, "", 1)
body = re.sub(r"^\s*<hr\s*/?>\s*", "", body, count=1)

# pandoc's gfm reader already assigns heading ids -- read them for the nav
# rather than injecting a second id attribute, which browsers ignore and which
# left 4 of the 25 headings unlisted
# NB \s+ not a literal space: pandoc wraps the tag onto a second line when the
# generated id is long, which silently cost four sections their nav entry
nav = [(m.group(1), m.group(2), m.group(3))
       for m in re.finditer(r'<h([23])\s+id="([^"]+)"[^>]*>(.*?)</h\1>', body, re.S)]

# wide content scrolls in its own container, never the page
body = re.sub(r"(<table>.*?</table>)", r'<div class="scroll">\1</div>',
              body, flags=re.S)
body = re.sub(r"(<pre>.*?</pre>)", r'<div class="scroll code">\1</div>',
              body, flags=re.S)

# [opus] / [obus] read as ownership tags, so mark them as such
body = re.sub(r"<code>\[(opus|obus)\]</code>",
              lambda m: '<span class="pkg pkg-%s">%s</span>' % (m.group(1), m.group(1)),
              body)

# ICES encodes its verdict as a cell fill; carry the real fills as swatches
FILLS = {
    "ok": None,
    "remove check": "#f80000",
    "change from warning to error": "#e06808",
    "change field range": "#f8f800",
    "add check": "#90d050",
    "question about the check": "#00b0f0",
    "correct, but modifications required": "#f8c000",
    "suggestion for new error-message text": "#f8d0b0",
    "change from error to warning": "#b0a0c0",
}
def swatch(m):
    inner = m.group(1)
    plain = re.sub(r"<[^>]+>", "", inner).strip().lower()
    fill = FILLS.get(plain, "MISS")
    if fill == "MISS":
        return m.group(0)
    dot = ('<i class="sw" style="background:%s"></i>' % fill) if fill else \
          '<i class="sw sw-none"></i>'
    return "<td>%s%s</td>" % (dot, inner)
body = re.sub(r"<td>(.*?)</td>", swatch, body, flags=re.S)

navhtml = "\n".join(
    '<a class="n%s" href="#%s">%s</a>' % (lvl, i, re.sub(r"<[^>]+>", "", t))
    for lvl, i, t in nav)

FACTS = [
    ("150,217", "hauls in HH", "1965&ndash;2026, 22 surveys a year since 2016"),
    ("9&ndash;26% &rarr; 84&ndash;87%", "count chain holds",
     "1977&ndash;95 against 2018&ndash;25, stepping at 1996 and 2004"),
    ("66%", "of ICES&rsquo;s own range checks marked <em>ok</em>",
     "29 marked <em>remove</em>, 26 <em>warning &rarr; error</em>"),
    ("0.96%", "of groups are real defects",
     "why <code>kind</code> is a routing label, not a severity"),
]
facts = "\n".join(
    '<div class="fact"><div class="fig">%s</div><div class="lab">%s</div>'
    '<div class="sub">%s</div></div>' % f for f in FACTS)

PAGE = """<title>DATRAS Check Suite</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,600;1,6..72,400&family=Source+Sans+3:ital,wght@0,400;0,600;1,400&family=IBM+Plex+Mono:wght@400;600&display=swap">
<style>
:root{
  --ground:#eef3f3; --surface:#fbfdfd; --surface-2:#e6eeed;
  --ink:#121e1e; --ink-dim:#4d5f5e; --ink-faint:#7c8d8c;
  --accent:#0b6467; --accent-soft:#d3e6e5;
  --rule:#cfdcdb; --rule-soft:#e0eae9;
  --display:"Newsreader",Georgia,"Times New Roman",serif;
  --body:"Source Sans 3","Helvetica Neue",Arial,sans-serif;
  --mono:"IBM Plex Mono",ui-monospace,"SFMono-Regular",Menlo,monospace;
  --measure:66ch;
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --ground:#0c1414; --surface:#131e1e; --surface-2:#1a2726;
    --ink:#dfebea; --ink-dim:#9fb3b2; --ink-faint:#758988;
    --accent:#4fbdbf; --accent-soft:#1b3a3a;
    --rule:#263433; --rule-soft:#1e2b2a;
  }
}
:root[data-theme="dark"]{
  --ground:#0c1414; --surface:#131e1e; --surface-2:#1a2726;
  --ink:#dfebea; --ink-dim:#9fb3b2; --ink-faint:#758988;
  --accent:#4fbdbf; --accent-soft:#1b3a3a;
  --rule:#263433; --rule-soft:#1e2b2a;
}
*{box-sizing:border-box}
body{background:var(--ground);color:var(--ink);font-family:var(--body);
  font-size:17px;line-height:1.65;-webkit-font-smoothing:antialiased}
.wrap{max-width:1180px;margin:0 auto;padding:0 28px 96px;
  display:grid;grid-template-columns:1fr;gap:0}
@media(min-width:1000px){
  .wrap{grid-template-columns:216px minmax(0,1fr);gap:56px;padding-top:8px}
}

/* masthead ------------------------------------------------------------- */
header.mast{grid-column:1/-1;padding:56px 0 30px;border-bottom:1px solid var(--rule)}
.eyebrow{font-family:var(--mono);font-size:11.5px;letter-spacing:.14em;
  text-transform:uppercase;color:var(--accent);margin:0 0 18px}
h1{font-family:var(--display);font-weight:600;font-size:clamp(2.1rem,5.2vw,3.35rem);
  line-height:1.06;letter-spacing:-.018em;margin:0;text-wrap:balance;max-width:24ch}
.mast .lede{max-width:var(--measure);margin-top:20px;color:var(--ink-dim);font-size:17px}
.mast .lede p{margin:.55em 0}
.mast .lede strong{color:var(--ink);font-weight:600}

/* facts strip ---------------------------------------------------------- */
.facts{grid-column:1/-1;display:grid;gap:1px;background:var(--rule);
  border:1px solid var(--rule);margin:34px 0 8px;
  grid-template-columns:repeat(auto-fit,minmax(210px,1fr))}
.fact{background:var(--surface);padding:16px 18px 18px}
.fact .fig{font-family:var(--display);font-size:1.5rem;font-weight:600;
  line-height:1.15;letter-spacing:-.01em;font-variant-numeric:tabular-nums}
.fact .lab{font-size:14px;color:var(--ink);margin-top:3px}
.fact .sub{font-size:12.5px;color:var(--ink-faint);margin-top:7px;line-height:1.45}
.fact code{font-size:11.5px}

/* nav ------------------------------------------------------------------ */
nav{display:none}
@media(min-width:1000px){
  nav{display:block;grid-column:1;align-self:start;position:sticky;top:20px;
    max-height:calc(100vh - 40px);overflow-y:auto;padding:34px 0 20px;
    font-size:13.5px;line-height:1.4}
  nav a{display:block;color:var(--ink-dim);text-decoration:none;
    padding:3.5px 0 3.5px 11px;border-left:2px solid transparent}
  nav a:hover{color:var(--accent);border-left-color:var(--accent)}
  nav a:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
  nav a.n2{color:var(--ink);font-weight:600;margin-top:13px;font-size:14px}
  nav a.n2:first-child{margin-top:0}
}

/* article -------------------------------------------------------------- */
article{grid-column:1;min-width:0;padding-top:34px}
@media(min-width:1000px){article{grid-column:2}}
article>*{max-width:var(--measure)}
h2{font-family:var(--display);font-weight:600;font-size:1.85rem;line-height:1.18;
  letter-spacing:-.012em;margin:56px 0 4px;padding-top:22px;
  border-top:1px solid var(--rule);text-wrap:balance;max-width:34ch}
h3{font-family:var(--display);font-weight:600;font-size:1.24rem;line-height:1.3;
  margin:38px 0 2px;text-wrap:balance;max-width:44ch}
h4{font-family:var(--body);font-weight:600;font-size:1rem;margin:26px 0 0}
p{margin:.85em 0}
a{color:var(--accent);text-decoration-thickness:1px;text-underline-offset:2px}
strong{font-weight:600}
em{font-style:italic}
ul,ol{padding-left:1.35em;margin:.85em 0}
li{margin:.32em 0}
li>ul,li>ol{margin:.3em 0}
hr{border:0;border-top:1px solid var(--rule-soft);margin:44px 0;max-width:var(--measure)}
blockquote{margin:1.1em 0;padding:2px 0 2px 18px;border-left:2px solid var(--accent-soft);
  color:var(--ink-dim);font-style:italic}

/* code ----------------------------------------------------------------- */
code{font-family:var(--mono);font-size:.855em;background:var(--surface-2);
  padding:.11em .34em;border-radius:2px;color:var(--ink)}
h2 code,h3 code{font-size:.8em;background:none;padding:0}
.scroll{overflow-x:auto;max-width:none;margin:22px 0}
@media(min-width:1000px){.scroll{margin-right:-40px}}
.scroll.code pre{margin:0;background:var(--surface);border:1px solid var(--rule);
  border-left:3px solid var(--accent-soft);padding:18px 20px;
  font-family:var(--mono);font-size:12.6px;line-height:1.6;min-width:min-content}
.scroll.code pre code{background:none;padding:0;font-size:inherit;white-space:pre}

/* tables --------------------------------------------------------------- */
table{border-collapse:collapse;font-size:14.5px;min-width:100%;
  font-variant-numeric:tabular-nums}
th{text-align:left;font-family:var(--mono);font-size:11px;letter-spacing:.09em;
  text-transform:uppercase;color:var(--ink-faint);font-weight:400;
  padding:0 16px 7px 0;border-bottom:1px solid var(--rule);white-space:nowrap}
td{padding:8px 16px 8px 0;border-bottom:1px solid var(--rule-soft);
  vertical-align:top;line-height:1.5}
tr:last-child td{border-bottom:0}
td code{font-size:.82em}

/* the swatches are ICES's own cell fills from WKDATR13 ------------------ */
.sw{display:inline-block;width:9px;height:9px;margin-right:7px;
  border-radius:1px;vertical-align:.05em;border:1px solid rgba(0,0,0,.22)}
.sw-none{background:var(--surface);border-color:var(--rule)}

/* package ownership tags ----------------------------------------------- */
.pkg{font-family:var(--mono);font-size:10.5px;letter-spacing:.06em;
  text-transform:uppercase;padding:2px 6px;border-radius:2px;
  vertical-align:.12em;white-space:nowrap;font-weight:600}
.pkg-opus{background:var(--accent-soft);color:var(--accent)}
.pkg-obus{background:var(--surface-2);color:var(--ink-dim);
  border:1px solid var(--rule)}
h2 .pkg,h3 .pkg{vertical-align:.2em}

footer{grid-column:1/-1;margin-top:70px;padding-top:22px;
  border-top:1px solid var(--rule);font-size:13px;color:var(--ink-faint);
  font-family:var(--mono);line-height:1.7}
footer a{color:var(--ink-dim)}
@media(prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}
</style>

<div class="wrap">
<header class="mast">
  <p class="eyebrow">obus &middot; proposal &middot; 2026-09-08</p>
  <h1>A QC check suite for HH, HL and CA</h1>
  <div class="lede">__LEDE__</div>
</header>

<div class="facts">__FACTS__</div>

<nav aria-label="Sections">__NAV__</nav>

<article>__BODY__</article>

<footer>
  obus/PLAN-qc-checks.md &mdash; pseudocode only, nothing built.<br>
  Sources extracted to imbus/DATRAS/external/ &mdash; see README_WKDATR13.md.
</footer>
</div>
"""

page = (PAGE.replace("__LEDE__", "\n".join(lede))
            .replace("__FACTS__", facts)
            .replace("__NAV__", navhtml)
            .replace("__BODY__", body))
open(OUT, "w", encoding="utf-8").write(page)
print("wrote %s  (%.1f KB, %d nav entries)" % (OUT, len(page) / 1024, len(nav)))
