---
name: folio
description: Write a self-contained HTML page (incident RCA or timeline, investigation, experiment readout, cost analysis, design, runbook, dashboard or tool), choose its Folio folder, and publish it to the team's Folio library with the folio MCP server. Use when the user asks for an HTML report, page or artifact, a write-up to share with the team, or to publish or update something in Folio.
---

# Folio pages

Folio is the team's library of HTML pages. Each page is one HTML file stored in GCS
at `<folder>/<slug>.html` and listed on the Folio site. **You** write the page and
**you** choose its folder; the `folio` MCP server only uploads what you send.

## Workflow

1. **Get the facts first.** A page reports findings. Run the queries, read the code,
   and keep the exact numbers, time windows and query text. Don't publish guesses as facts.
2. **Check for an existing page.** Call `list_pages(query=...)`. If the user is
   continuing earlier work, update that page (`update_id`) instead of starting a new one.
3. **Choose the folder** with the rules below. Call `list_folders` and reuse what exists.
4. **Write the page** to a local file named after the slug, e.g. `rtb-nic-overhead.html`.
   Start from `template.html` next to this file (or the `folio://template` resource, or
   `get_page_guide`). Keep its tokens and type scale; delete the parts you don't need.
5. **Check it** against the checklist at the end.
6. **Publish** with `publish_page`: `title`, `description`, `folder`, `service`, `tags`,
   `author`, and `html` (the shared server can't read your files; `file_path` works only
   when `folio mcp` runs on your machine).
7. **Reply** with the URL, the folder, and one sentence on what the page says. If the
   tool returned `notes`, fix the cause in your file so the next revision is clean.

## Choosing the folder

Decide by the page's purpose, meaning what the reader will do with it, not by words that
happen to appear in it.

| Folder | Use it when the page… | Examples |
|---|---|---|
| `incidents` | explains something that broke or degraded for users, customers or an SLO: impact, timeline, root cause, actions | outage in Singapore, DB refresh saturation RCA, bad deploy postmortem |
| `investigations` | explains how a system behaves or why it costs what it does, when nothing broke | NIC overhead per pod, cache contention on a onebox, p99 latency drift |
| `experiments` | compares a test against a control on purpose and reports a result or decision | 16c vs 32c onebox readout, canary of a new GC setting, load test |
| `cost` | has money as its headline: spend, egress, rightsizing, commitments, savings | Prebid egress cost analysis, node pool rightsizing plan |
| `architecture` | proposes or documents a design: components, data flow, options, trade-offs | anomaly-agent design, MCP gateway proposal |
| `runbooks` | tells someone how to do a task step by step | Istio upgrade procedure, on-call guide for ProxySQL |
| `dashboards` | is mostly charts or tables meant to be re-read as a snapshot | weekly fleet CPU overview, cert expiry tracker |
| `tools` | is interactive: the reader enters values and gets an answer | capacity calculator, PromQL builder |
| `planning` | covers goals and progress: roadmaps, quarterly or mid-year reviews, retros, status updates | Q4 SRE roadmap, mid-year review |
| `notes` | fits none of the above: explainers, references, summaries | glossary of bidder metrics |

Tie-breakers:

- Customer or SLO impact makes it `incidents`, even when most of the page is analysis.
- An investigation whose conclusion is a dollar figure goes to `cost`; one whose
  conclusion is CPU, memory or latency stays in `investigations`.
- A deliberate control/test comparison is `experiments`, even on a onebox.
- Future work is `architecture`; instructions for doing work are `runbooks`.
- Don't invent folders. If none fits, use `notes`. Create a new folder only when the user
  asks, as a lowercase plural noun with hyphens (`load-tests`).
- When updating a page, keep its folder unless its purpose changed. Changing the folder
  moves the page; old links redirect.

## Page details you send

- **title**: under 60 characters, names the subject: "rtb NIC overhead", not
  "Investigation report". Use the same text in `<title>` and `<h1>`.
- **description**: one or two plain sentences with the finding, shown under the title in
  Folio and searched. "Every rtb pod spends 0.6 to 1.5 cores on kernel network work; on
  N2D pools that is 10 to 12% of busy CPU."
- **service**: the main service, lowercase: `rtb`, `mowx`, `adex`, `bss`, `envoy`,
  `ip-service`, `forecasting`, `prebid`, `istio`, `proxysql`, `cortex`, `heimdall`.
  Leave it out when the page spans many services.
- **tags**: 2 to 5 short lowercase words that help search: region, component, technique
  (`singapore`, `softirq`, `node-pools`). Don't repeat the folder or service.
- **author**: your user's name, e.g. from `git config user.name`. The shared server can't
  tell who is publishing, so always send it.

## Hard rules (Folio enforces these)

Folio shows every page in a sandboxed frame with a strict content policy.

- **One file.** Inline all CSS and JS. Scripts may load only from `cdnjs.cloudflare.com`,
  `cdn.jsdelivr.net` or `unpkg.com`, pinned to an exact version; fonts only from Google
  Fonts. No `fetch`, XHR or WebSocket: embed the data in the page as a JSON `<script>`.
- **Images** as inline SVG or `data:` URIs. Don't link Grafana or other internal images;
  they need a login and show as broken.
- **No browser storage or dialogs.** The frame has no origin, so `localStorage` and
  cookies throw (wrap any use in try/catch), and `alert`/`confirm`/`prompt` are blocked.
  Forms submit nowhere; handle them in JS.
- **Both themes.** Light tokens on `:root`; dark tokens under both
  `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { … } }` and
  `:root[data-theme="dark"] { … }`. Folio sets `data-theme` on `<html>` when the reader
  picks a theme. Always give `body` a background.
- **Works at 400px wide** with no sideways page scroll. Wide tables, code and diagrams go
  in their own `overflow-x: auto` box.
- **A full document**: `<!doctype html>`, `<html lang="en">`, charset, viewport, `<title>`.
- **Under 8 MB**; aim for under 300 KB.

## Writing

- **Answer first.** The first screen says what happened or what we found, how big it is,
  and what to do, in two or three sentences with the numbers.
- **Plain and factual.** Short sentences. Every number has a unit and a time window;
  incident times are UTC. No self-praise or filler ("robust", "comprehensive",
  "seamless", "it's worth noting").
- **Say how sure you are.** Mark claims `measured` (queried; the query is on the page),
  `inferred` (reasoned from measurements) or `unconfirmed` (a hypothesis), using the
  template's `.ev` labels.
- **Show your work.** Put the PromQL, SQL or kubectl you ran in a "Method and limits"
  section so a teammate can rerun it, and say what would change the conclusion.
- **Use the team's names** for things: pod, node pool, namespace, region.

## Structure by folder

- **incidents**: summary (impact, duration, status), timeline in UTC, root cause ·
  contributing factors, actions with owners, method.
- **investigations**: answer, key figures, evidence (charts, tables), explanation ·
  recommendations ranked by payoff, checks to run, method and limits.
- **experiments**: result and decision, setup (hypothesis, control vs test, traffic,
  window), results with deltas and spread, caveats, next step.
- **cost**: headline spend or saving per month, breakdown, drivers, options with their
  dollar effect, pricing assumptions.
- **architecture**: problem, proposal with a diagram, options considered, risks ·
  rollout.
- **runbooks**: when to use it, prerequisites, numbered steps with copyable commands ·
  how to verify, how to roll back.
- **dashboards** and **tools**: one screen, controls in one row above the data, and the
  time the data was captured.
- **planning**: outcomes first, then detail by goal.

## Design

The template is the house style, so pages look related in Folio. Keep it; don't restyle
per page.

- Reading column up to 70ch; charts and tables may use the full 1040px.
- Use the template's type scale and fonts. Don't add sizes or typefaces.
- Colour carries meaning only (see the comment at the top of the template). Status
  colours always come with a text label.
- Big numbers only when the headline is a number, four at most.
- Avoid template clichés: no all-caps eyebrow labels above headings, no emoji, no
  gradient banners, no card grids for prose, no arrows appended to links, no middle dots
  joining metadata (use the labeled `.meta` list).
- Number things only when they are a real sequence (steps, ranked recommendations).

**Charts.** Inline SVG for small data; Chart.js from cdnjs for many points.
- One y-axis. Two measures on different scales get two charts.
- Series colours are `--s1`, `--s2`, … in that order; never cycle or reorder them, and a
  seventh series folds into "Other". Magnitude uses one hue from light to dark.
- A legend for two or more series, plus direct labels when there are four or fewer.
  Text stays in ink colours, never the series colour.
- Every mark gets a hover and focus tooltip with the exact value (`data-tip` in the
  template). In light mode some series colours are pale, so label values on the chart or
  add the numbers as a table.
- Thin marks: bars with a 4px rounded end and a 2px gap, 2px lines, a recessive grid.

**Diagrams.** Inline SVG, or Mermaid in `<pre class="mermaid">` with Mermaid loaded from
cdn.jsdelivr.net. Check that it reads in both themes.

## Checklist before publishing

- The title and first screen state the finding.
- Every number has a unit and a time window; incident times are UTC.
- Evidence labels on the claims that matter; queries in the method section.
- Readable at 400px wide with no sideways scroll; dark mode has both blocks.
- No requests beyond the allowed CDNs and Google Fonts.
- Folder chosen with the rules above; description, service and tags filled in.

## Updating a page

Call `publish_page` again with `update_id` set to the page's id (for example
`investigations/rtb-nic-overhead`) and all the details. The URL stays the same and the
revision number goes up. Use `get_page(page_id, include_html=true)` to fetch the current
HTML when you don't have the file.

## If the Folio tools aren't available

Save the page locally and tell the user to connect the server: the "Publish from your
agent" link on the Folio site shows the exact command.
