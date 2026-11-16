---
name: ywli-site-optimizer
description: Audit and optimize SilverStripe 6 client sites for technical SEO, content SEO (DE/BS/HR/SR), Lighthouse ≥90 in all four categories on mobile and desktop, WCAG 2.2 AA, and AEO/GEO (visibility and citations in ChatGPT, Claude, Perplexity, Gemini, Google AI Overviews). Report first (presentation + detailed PDF), then code PR and CMS draft content changes after explicit approval. Also has an audit-only mode for any website with public HTTP access only (prospects, other CMSs): crawl + Lighthouse + axe → PDF action plan. Use for any SEO audit, AEO/GEO/AI-search visibility check, PageSpeed/Lighthouse/Core Web Vitals work, accessibility/barrierefreiheit/BFSG check, or "optimize this site" request, even if only one of these areas is named.
---

# YWLI Site Optimizer

YouWillLikeIT service workflow for client sites, primarily SilverStripe 6 (Elemental, Vite, optionally Fluent), developed locally with **DDEV on Windows/WSL2**.

Targets:
- **Lighthouse ≥90** in Performance, Accessibility, Best Practices and SEO, on **mobile and desktop**, on **every indexable URL**
- **WCAG 2.2 AA**
- Clean technical and content SEO for DACH (DE) and BiH/HR/RS (BS/HR/SR)
- **AEO/GEO:** AI search and answer engines can reach, understand and cite the site

The work runs in phases with a human gate. The client sees a report before anything changes. Nothing is published without the operator doing it himself.

```
Phase 0 Intake → Phase 1 Audit → Report (slides PDF + detailed PDF) → GATE (approval + access)
  → Phase 2 Fixes (code PR + CMS content as DRAFT) → Phase 3 Verify → final before/after report
```

## Ground rules

- **Authorization:** only audit sites the operator says he is authorized to work on.
- **Credentials:** they live only in `clients/<slug>/.env` (chmod 600). They never go into chat, reports, commits or logs. If a secret shows up in chat, tell the operator to rotate it after the project.
- **Production:** never write to it. Code goes to a branch plus a PR. CMS content goes to the **Draft stage only**. Never call `publish*()` or press Publish.
- **URLs:** never change existing URLs/URLSegments without explicit approval. If approved, add a 301 for each change.
- **Lighthouse variance:** a URL fails only if the **median of 3 runs** is below 90.
- **Automated a11y tools** catch only part of all WCAG failures. The manual checklist is mandatory before claiming AA.
- **Report numbers** come from files in `runs/`, never estimated. If a check could not run (auth, timeout, blocked), the report says so.

## Environment (WSL2 + DDEV)

Everything runs inside WSL (Ubuntu), in VS Code connected to WSL. Keep the workspace on the Linux filesystem (`~/…`), not under `/mnt/c`, which is much slower.

```
~/ywli-optimizer/
  tools/                    copy of this skill's scripts/ + node_modules
  clients/<slug>/
    project.yml             from templates/project.yml.example
    .env                    from templates/env.example (chmod 600)
    runs/<YYYYMMDD>-before/ crawl.jsonl, crawl-issues.json, urls.txt, lh/, axe/, gsc.jsonl, findings.json
    runs/<YYYYMMDD>-after/
    reports/                *.html sources + *.pdf
```
Client repos stay where the operator keeps his DDEV projects (`repo.path`).

### Preflight (once per machine, and after a skill update)
This skill's base directory is shown when the skill loads. `scripts/` and `templates/` are relative to it.
```bash
node -v                      # need >= 20 inside WSL (nvm recommended)
ddev version; git --version; gh --version   # gh only for GitHub PRs
mkdir -p ~/ywli-optimizer/tools && cp <skill-dir>/scripts/* ~/ywli-optimizer/tools/
cd ~/ywli-optimizer/tools && npm install
npx puppeteer browsers install chrome --install-deps   # Chrome + Linux libs (sudo)
export CHROME_PATH="$(node -e "import('puppeteer').then(m=>console.log(m.default.executablePath()))")"
```
Put `CHROME_PATH` into `~/.bashrc` so Lighthouse uses the same Chrome.

If `--install-deps` is not supported, install the libs manually: `sudo apt-get install -y libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2` plus `libasound2t64` (Ubuntu 24.04) or `libasound2` (older).

If anything is missing, tell the operator the exact command and stop.

### Loading env for a client
```bash
cd ~/ywli-optimizer/clients/<slug> && set -a && source .env && set +a
```

### Local DDEV targets
- Tools reach `https://<project>.ddev.site` directly from WSL.
- For the mkcert certificate, prefer `NODE_EXTRA_CA_CERTS="$(mkcert -CAROOT)/rootCA.pem"` for crawl/gsc. `YWLI_INSECURE=1` is the fallback, and only for `*.ddev.site`.
- Local Performance scores are not representative (no CDN, dev mode, Docker I/O). Use local runs for a11y/SEO checks and regression direction. Measure with `SS_ENVIRONMENT_TYPE="live"` and a flushed cache.
- **Final numbers always come from staging.**

### Long runs
Lighthouse needs roughly 15–25 s per URL per device. Before starting, tell the operator the estimate (URLs × 2 devices × ~20 s). Run in the background and poll:
```bash
nohup node ~/ywli-optimizer/tools/lh.mjs urls.txt mobile lh > logs/lh-mobile.log 2>&1 &
tail -n 5 logs/lh-mobile.log
```

## Running in claude.ai (cloud session)

Phase 1 and audit-only work entirely in a claude.ai cloud session. Phase 2 code work stays in VS Code/WSL with DDEV.

**Network:**
- The sandbox reaches websites only if the account allows network egress to **all domains**. On a paid individual plan the person sets this in claude.ai Settings → Capabilities; on Team/Enterprise an admin sets it in Organization settings → Capabilities.
- Check first: `curl -sS -o /dev/null -w "%{http_code}" https://<site>/`. A `CONNECT tunnel failed, response 403` means egress is not enabled. Tell the operator and stop.

**Tools:**
- Attach the private repo `you-will-like-it/claude-skills` to the session (repo-attach tool, read access) and clone it shallow.
- Copy `plugins/ywli-site-optimizer/skills/ywli-site-optimizer/scripts/*` to `~/ywli-optimizer/tools/`.
- Run `npm install` and `npx puppeteer browsers install chrome --install-deps`, then export `CHROME_PATH` as in the preflight.

**Workspace:**
- `~/ywli-optimizer/clients/<domain>/` inside the sandbox. It does **not** persist across sessions.
- Send the PDFs with the file-sending tool. If the session is in a claude.ai Project, also save a short summary there.

**Long runs:**
- Background processes stop shortly after a reply ends. Run Lighthouse in the foreground, in chunks that finish within ~9 minutes (about 10 URLs per device per chunk; `lh.mjs` appends to the same CSV).
- Keep the audit-only sample at ≤30 URLs.

**GSC:** only if the operator uploads a CSV export.

## Audit-only mode (public HTTP access only)

Use this mode when the operator has nothing but the public URL. Typical cases: a prospect or sales pitch, a site on another CMS, or a client who only wants a list of measures. It runs Phase 1 and the report, then **ends**. There is no gate and no Phase 2.

**Works without access:**
- crawl and technical SEO
- Lighthouse and axe
- the manual WCAG checklist, done in a browser
- on-page content SEO
- AEO/GEO checks: AI-bot access, rendering, entity and structure signals. The panel is optional.

**Missing data:**
- **No GSC:** no query data, so no striking-distance, CTR or cannibalization analysis. Content SEO is based on the page content only. Say so in the report, and list GSC access as the next step for a deeper analysis.
- **No code:** findings are phrased by symptom and template, not by file. Recommendations follow the detected stack (`stack` in `crawl-issues.json`: WordPress, TYPO3, Shopify, Wix, SilverStripe, …). Name a platform-specific fix only when you are confident it applies. Otherwise describe what must change, not how.

**Load and scope (third-party server):**
- Crawl with `YWLI_POLITE=1`: one request at a time, 1 s apart.
- Lighthouse only on a **sample**: every page type that `crawl.jsonl` shows (by URL pattern and heading/element structure), 1–3 URLs each, plus the home page and the main money pages. Mobile + desktop, median of 3.
- axe on the same sample.
- State the sampling in the report.

**Report:**
- Same two PDFs: the presentation plus the detailed "Maßnahmenkatalog / Plan mjera".
- Use **YouWillLikeIT branding** (the site owner is not yet a client) with the site's name and screenshot on the title slide.
- Every measure gets priority, effort (S/M/L) and the expected impact area (SEO / AEO / Performance / A11y / legal).
- The last slide is the offer hook: what YouWillLikeIT can implement and what access would be needed (see Phase 0).
- Don't claim anything that requires data you didn't have (rankings, traffic, conversions).

Store runs under `clients/<domain>/` with a minimal `project.yml` (`site`, `report_language`, `mode: audit-only`).

## Phase 0: Intake

Create `clients/<slug>/project.yml` and `.env` from `templates/`. Ask only for what is missing.

**Access needed for Phase 1 (read-only):**
- site/staging URLs
- staging basic auth
- GSC: a service-account e-mail added as a *Restricted* user, or the operator's CSV export (Performance → Pages + Queries, 16 months)

Repo and CMS access are requested at the gate, not before.

## Phase 1: Audit

Baseline against **production** (read-only), or staging if production is not live. `R=runs/$(date +%Y%m%d)-before`, `T=~/ywli-optimizer/tools`.

1. **Crawl:** `node $T/crawl.mjs <site> 5000 > $R/crawl.jsonl`
2. **Analyze:** `node $T/analyze-crawl.mjs $R/crawl.jsonl $R <site>`. This writes `urls.txt` (200, HTML, indexable, self-canonical) and `crawl-issues.json`.
3. **Lighthouse:**
   - `node $T/lh.mjs $R/urls.txt mobile $R/lh` and `… desktop $R/lh`
   - Collect every URL with any category <93 into `recheck.txt`
   - Rerun those with `runs=3` into `$R/lh-median`. The median result is authoritative.
4. **axe:**
   - `node $T/axe.mjs $R/urls.txt $R/axe`
   - Also run `node $T/axe.mjs <one-url-per-template.txt> $R/axe 375`, because some violations only appear in the mobile layout.
   - Treat `incomplete` items as candidates for manual checking, not as passes.
5. **GSC:** `node $T/gsc.mjs <property> $R/gsc.jsonl 16`, or normalize the operator's CSV into the same fields.
5a. **AI access:** `node $T/ai-access.mjs <site> $R/ai-access.json $R/urls.txt` (robots.txt per AI bot, WAF probe, llms.txt).
5b. **Rendering:** `node $T/render-diff.mjs <one-url-per-template.txt> $R/render-diff.json`. This flags pages whose content exists only after JavaScript.
5c. **AI visibility panel** (optional, only if the operator wants it and API keys are set): `node $T/aeo-panel.mjs panel.json $R/aeo`. See AEO/GEO below.
6. **Code read** (if repo access already exists): `Page.ss` and layouts, Elemental block templates, `vite.config.*`, `app/_config/*.yml`, `composer.json`, `.ddev/config.yaml`.
7. **Manual WCAG 2.2 checks:** one URL per PageType and per element type (checklist below).
8. **Normalize** everything into `$R/findings.json`. Group by **template/PageType**, not by URL: one template fix usually resolves hundreds of URL-level issues, and the report must make that visible.
```json
{"id":"A11Y-012","category":"tech-seo|content-seo|aeo|performance|a11y|best-practices",
 "severity":"critical|high|medium|low","wcag":"1.4.3","title":"…","evidence":"…",
 "urls":["…"],"urlCount":214,"template":"BlogPost / ElementContent","fix":"…",
 "effort":"S|M|L","needs":"repo|cms|client-decision"}
```

### What to check

**Technical SEO** (most of this is already in `crawl-issues.json`):
- status codes, redirect chains, broken internal links
- canonicals: absolute, self-referencing, consistent www/https/trailing slash
- robots.txt, meta robots and X-Robots-Tag: staging must be noindex, production must not be
- XML sitemap: only 200 + indexable + canonical URLs (`wilr/silverstripe-googlesitemaps`)
- `<html lang>` per locale
- hreflang: reciprocal, x-default, matches the canonical. Check whether Fluent already outputs hreflang before adding custom tags.
- duplicates, orphans, click depth
- JSON-LD validity. For SS6 the standard is `dorsetdigital/silverstripe-schema-manager` (see AEO/GEO and Phase 2).
- OG tags, mixed content, HTTPS/HSTS

**Content SEO:**
- exactly one H1 per page, no skipped heading levels. Elemental block titles often break the hierarchy, so block titles default to h2.
- title ~50–60 chars with the main term early
- meta description ~120–158 chars with a concrete benefit
- thin money pages (<300 words)
- alt text that describes the image (not filenames, not "Bild")
- descriptive internal anchor text

From `gsc.jsonl`:
- **striking distance:** queries with relevant impressions at position 4–20 → strengthen the ranking page (content, headings, internal links)
- **low CTR:** CTR well below other queries at similar positions → rewrite the title/meta
- **cannibalization:** several URLs for one query → merge or differentiate

**Language:**
- **DE:** native, natural German. Keep the site's Sie/du form. No literal translations.
- **BS/HR/SR:** follow `content_language_variant` (script, ijekavica/ekavica). Never mix variants on one site.

**Performance** (lab targets: LCP ≤2.5 s, CLS ≤0.1, TBT as the INP proxy; field data from the GSC CWV report):
- LCP image: not lazy, `fetchpriority="high"`, preloaded if it is a CSS background
- images: WebP/AVIF, width/height set
- render-blocking CSS/JS, unused JS
- fonts: self-hosted, `font-display: swap`, preload. Self-hosting also avoids the Google-Fonts DSGVO problem in DE.
- third parties: GTM, cookie banner, maps, video. Use facades / consent-gated loading.
- caching and compression

**AEO / GEO (answer engines, AI search).** Data comes from `crawl-issues.json` (`aeo-*`), `ai-access.json`, `render-diff.json` and optionally `aeo/`.

1. **Access for AI crawlers** (highest impact, cheapest fix):
   - Each vendor runs separate bots: *search* (builds the index answers cite from: OAI-SearchBot, Claude-SearchBot, PerplexityBot; Googlebot for AI Overviews; Bingbot for Copilot), *user* fetchers (ChatGPT-User, Claude-User, Perplexity-User), and *training* (GPTBot, ClaudeBot, CCBot, meta-externalagent; control tokens Google-Extended and Applebot-Extended).
   - Search bots and user fetchers blocked by robots.txt or by a WAF/CDN (Cloudflare "AI bots" settings, bot-fight mode) is a **high** finding.
   - Training access is the **client's decision**. Present it neutrally; never block or allow it on our own.
   - Google-Extended does not affect AI Overviews; those follow Googlebot.
   - The WAF probe runs from our IP with the bot's user agent, so it is indicative. Ask the client to confirm in the CDN settings or server logs.
2. **Content without JavaScript:** most AI crawlers don't execute JS. Pages flagged `jsDependent` lose their content for them. SS6 renders server-side, so this mostly matters for prospects on SPA stacks and for JS-injected sections (tabs, accordions, sliders filled via JS).
3. **Entity and trust signals:**
   - `Organization`/`LocalBusiness` schema with name, logo, address, contact and `sameAs` links (Google Business profile, LinkedIn, Wikidata, social profiles)
   - consistent name, address and phone (NAP) across the site and the profiles
   - authors as `Person` with an author page on articles
   - `dateModified` on content pages
   - Impressum, "Über uns"/"O nama", contact page
4. **Citable structure** (`aeo-*` findings):
   - question-style H2/H3 (how people ask) followed directly by a 40–60 word answer, then detail
   - definitions, lists and tables for comparisons, prices, steps
   - own numbers and facts with source and date
   - sections that make sense when quoted alone
   - FAQ blocks only where real questions exist, marked up as `FAQPage`
   - The crawl heuristics are a starting point; judge the actual content before writing findings.
5. **llms.txt:** informational only. It is a proposed standard without confirmed use by the major engines. Mention presence/absence, low priority; never sell it as a key measure.
6. **Measurement:**
   - **AI visibility panel** (optional): 10–20 real customer questions per client in the site's language, asked to Perplexity, ChatGPT, Claude and Gemini via API (`aeo-panel.mjs`). Record: site cited? brand mentioned? Results vary between runs, so report them as a snapshot with the date, never as rankings. Costs money per question and provider; only with the operator's keys and OK.
   - **Without API keys** (e.g. claude.ai): run the same questions through the session's own web search and record whether the domain appears in the results. Label this "search index presence", not AI citations.
   - Recommend GA4 tracking of AI referrals (`chatgpt.com`, `perplexity.ai`, `gemini.google.com`, `claude.ai`, `copilot.microsoft.com`) so effects become measurable.

**Accessibility, automated:** axe tags `wcag2a wcag2aa wcag21a wcag21aa wcag22aa best-practice`. Any critical/serious violation must be fixed.

**Accessibility, manual WCAG 2.2 AA checklist (per template):**
- full keyboard pass: tab order, no traps, skip link; menus, dialogs, accordions and tabs operable
- 2.4.7 focus visible, and 2.4.11 focus not obscured (sticky header, cookie banner)
- 2.5.8 target size ≥24×24 CSS px
- 2.5.7 alternatives to dragging (sliders, carousels)
- 1.4.3 / 1.4.11 contrast, including hover/focus states and text over images
- 1.4.10 reflow at 320 px, 1.4.12 text spacing, 1.4.13 content on hover/focus
- forms (UserForms): labels, error identification, 3.3.7 redundant entry
- 3.3.8 accessible authentication (login, captcha)
- 3.2.6 consistent help
- motion: `prefers-reduced-motion`, carousels can be paused
- link purpose, language of parts
- PDFs linked from the site: flag them, out of scope unless agreed

**BFSG (DE clients):** note whether the BFSG (in force since 28.06.2025) likely applies, e.g. B2C e-commerce or other consumer services. If so, the client needs a Barrierefreiheitserklärung. Flag this for legal review; don't give a legal verdict.

## Report (end of Phase 1)

Two deliverables in `report_language`. Both use the client logo and brand colors, with a "powered by YouWillLikeIT" footer. The reports themselves must meet WCAG AA contrast.

**Production:** write self-contained HTML (logo as a data URI, brand colors as CSS variables, system or embedded fonts, no external requests). Render with `node $T/render-pdf.mjs in.html out.pdf slides|a4`.

If Claude's Slides/Docs artifact types are available in the session (claude.ai), they can be used instead. They export to PDF/PPTX.

**A. Client presentation** (`slides`: one `<section class="slide">` per 1280×720 page, `break-after: page`):
1. Title: client, site, date
2. Executive summary: scores now vs. target, 3 key messages
3. Score matrix: PageType × mobile/desktop × 4 categories (red <50, amber 50–89, green ≥90)
4. Technical SEO: top issues with counts
5. Content opportunities from GSC: top queries/pages and why they matter
6. Accessibility: WCAG 2.2 AA status, top barriers, BFSG note (DE)
7. AI-Sichtbarkeit / AI vidljivost (AEO/GEO): AI-bot access matrix (search / user / training × allowed / blocked), entity and structure gaps, panel snapshot if run, training-crawler decision for the client
8. Performance / Core Web Vitals
9. Plan: work packages, effort, which items need client decisions (third parties, content, AI training policy)
10. Approval: what is needed (repo, CMS editor login, staging), next steps

**B. Detailed technical report** (`a4`):
- every finding from `findings.json`, grouped by category → template
- WCAG SC, evidence, fix, and affected URLs (truncate long lists; attach the full CSV)

Then **stop**.

## GATE

Ask the operator in one message:
- which work packages or finding IDs are approved (default: everything except `client-decision`)
- confirmation that repo access works (`git ls-remote <url>`) and that `.env` has staging and CMS credentials
- `cms_mode` for this client (`task` or `browser`)

Record the answers in `project.yml` (`approved_findings`). **Do not start Phase 2 without an explicit "go".**

## Phase 2: Fixes

### Code (PR)
- Work in `repo.path`. Create branch `ywli/opt-<YYYYMMDD>` from `repo.base`, with one commit per work package (`perf: …`, `a11y: …`, `seo: …`). Each commit message lists its finding IDs.
- **SilverStripe 6 patterns:**
  - **Document head:** `<html lang="$ContentLocale">`. Meta comes from `$MetaTags(false)` plus a controlled `<title>` pattern.
  - **Images:**
    - `$Image.ScaleWidth(…)`, with `.Convert('webp')` where the installed assets version supports it
    - explicit width/height, and srcset via a template loop
    - LCP image: `.LazyLoad(false)` plus `fetchpriority="high"`
    - Alt text defaults to the File Title. Check the image template and, where needed, add a dedicated alt field via an extension.
  - **Vite:** module scripts, per-element code splitting, critical CSS for above the fold, purge unused Tailwind/Bootstrap.
  - **Fonts:** self-hosted woff2, `font-display: swap`, preload 1–2 files.
  - **Caching:** `HTTPCacheControlMiddleware` for public pages, partial caching in heavy templates.
  - **Elemental:** configurable heading level per block, default h2. Exactly one h1 per page.
  - **UserForms:** labels, `aria-describedby` for errors, `autocomplete` attributes.
  - **Cookie banner:** `role="dialog"`, focus management, keyboard dismissable, doesn't obscure focus.
  - **Global:** `:focus-visible` styles, skip link, landmarks (`header`/`nav`/`main`/`footer`).
  - **robots.txt:** find out how the project serves it (static `public/robots.txt`, a robots module or a controller) and change it there. Use the AI groups from `templates/robots-ai.txt.example`, with the training block set to the client's decision. A bot matching a named group ignores `*`, so repeat the project's protected paths in each named group. WAF/CDN bot settings are outside the repo: list them for the client.
  - **Structured data:** `dorsetdigital/silverstripe-schema-manager` (needs PHP 8.3+ on SS6). It emits Organization, WebSite, WebPage and BreadcrumbList as one linked `@graph`, with Organization data managed in SiteConfig. Per-page types (FAQPage, Service, Event, Product, BlogPosting, Person, LocalBusiness …) come via the page's Schema tab or `SchemaRegistry::add()`. Extra properties go through the `updateSchemaManagerEntities(array &$entities)` hook. Enable `DorsetDigital\SchemaManager\Extension\BlogPostSchemaExtension` if the blog module is used.
    - Read the module's docs (README and the guides it links: site schema, developer API, FAQ, local businesses) in the installed vendor folder before coding. Check which Organization fields (sameAs, logo, address) SiteConfig offers, and add missing ones via the hook instead of a second JSON-LD block.
    - If the project already has another schema module or hand-written JSON-LD, remove the duplicates so there is one graph per page.
  - **AEO content:** question headings, direct answers, tables and FAQ sections are content changes. They go through the CMS changeset as drafts, not into templates, unless an Elemental block type is missing (e.g. FAQ block with `FAQPage` output).
- **Verify with DDEV before pushing:**
  1. `ddev composer install`, then `ddev npm ci && ddev npm run build` (or host npm, if the project builds on the host)
  2. `ddev exec vendor/bin/sake db:build --flush`
  3. run crawl/axe/Lighthouse against the local `*.ddev.site`, for the affected templates only
- **PR:**
  - GitHub: `gh pr create`
  - Bitbucket: push, then create the PR via the REST API with `BITBUCKET_TOKEN`, or give the operator the compare link
  - PR body: finding IDs, what changed per template, local before/after scores (marked "local, indicative")

### CMS content (DRAFT only)
Build `changeset.json` from the approved content findings. Every change carries the **exact current value** as `before`:
```json
{"meta":{"client":"…","generated":"…","source":"runs/…/findings.json"},
 "changes":[{"class":"Page","id":12,"locale":"de_DE","field":"MetaDescription",
              "before":"…exact current value…","after":"…","finding":"CSEO-004"}]}
```
The operator reviews `changeset.json` (render it as a readable before/after table) before anything is applied.

**`cms_mode: task`:**
- Add `templates/ApplySeoChangesetTask.php` to the project (`app/src/Tasks/`) in the PR.
- The file must be reachable inside the container. Put it at `<repo>/.ywli/changeset.json` and add `.ywli/` to `.gitignore`. The container path is then `/var/www/html/.ywli/changeset.json`.
- Run locally first: `ddev exec vendor/bin/sake tasks:ywli-apply-changeset --file=/var/www/html/.ywli/changeset.json --dry-run`, then without `--dry-run`. On staging the operator runs the same task (or you do, via SSH if he provides it).
- Conflicts mean the content was edited after the audit. Regenerate those entries; never force them.
- Before first use, check the BuildTask API against `vendor/silverstripe/framework/src/Dev/BuildTask.php`. The template targets SS 6.x (`PolyOutput`, `$commandName`).

**`cms_mode: browser`:**
- Use a browser tool (Claude in Chrome or the built-in browser) to log in on **staging** with the Content Editor account.
- Edit the fields and click **Save**, never Publish.
- Log each change into `changeset.json` so it stays reviewable and reversible.

The operator reviews the drafts in the CMS and publishes them himself.

## Phase 3: Verify

After the PR is deployed to staging and the operator has published the drafts:
- Rerun crawl, analyze, Lighthouse (both devices; median of 3 for anything <93) and axe into `runs/<date>-after/`. Repeat the manual checklist on the changed templates.
- **Pass criteria:** every indexable URL ≥90 in all four categories on both devices, and zero critical/serious axe violations.
- List every remaining failure with its cause. If the cause is client-side (e.g. a third-party script the client keeps), say so plainly.
- **Final report:** same two formats, plus a before/after section: score-matrix delta, fixed findings by ID, open items with owner, recommendations, and the Barrierefreiheitserklärung note for DE.

## Communication

Keep chat updates short: phase, what ran, headline numbers, next step. The detail belongs in the reports and in `runs/`.
