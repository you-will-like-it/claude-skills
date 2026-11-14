# ywli-site-optimizer

Audit and optimization workflow for SilverStripe 6 client sites under the YouWillLikeIT brand.

**Targets**
- Lighthouse ≥90 in Performance, Accessibility, Best Practices and SEO, on mobile and desktop, on every indexable URL
- WCAG 2.2 AA
- Clean technical and content SEO for DE (DACH) and BS/HR/SR

## Workflow

| Phase | Output | Changes anything? |
|---|---|---|
| 0 Intake | `project.yml`, `.env` per client | no |
| 1 Audit | crawl, Lighthouse, axe, GSC data, `findings.json` | no |
| Report | client presentation PDF (16:9) and detailed technical PDF (A4), client-branded, "powered by YouWillLikeIT" | no |
| **Gate** | operator approves findings and provides repo/CMS access | n/a |
| 2 Fixes | PR on GitHub/Bitbucket; CMS content written as **draft** (task or browser) | branch + drafts only |
| 3 Verify | rerun on staging, before/after report | no |

**Audit-only mode:** for any site with public HTTP access only (prospects, other CMSs). Runs Phase 1 politely, on a Lighthouse sample per page type, then produces the PDF action plan under YouWillLikeIT branding. Stops there.

Production is never written to. Content is never published by the skill.

## Prerequisites (Windows + WSL2)

- VS Code with the WSL extension, and the Claude Code extension installed **in the WSL window**
- Inside WSL: Node ≥20, git, DDEV, `gh` (for GitHub PRs)
- Chrome for headless runs, installed by the preflight: `npx puppeteer browsers install chrome --install-deps`

Preflight copies `skills/ywli-site-optimizer/scripts/` to `~/ywli-optimizer/tools/` and runs `npm install` there. Re-run it after updating the plugin.

## Install

```text
/plugin marketplace add you-will-like-it/claude-skills
/plugin install ywli-site-optimizer@ywli-skills
```

## Usage

Ask Claude in a WSL VS Code window, e.g.:

- "Audit https://www.example.de, client Muster GmbH, report in German."
- "Audit-only: https://www.prospect.de, they are on WordPress, we only have the URL. PDF action plan in German."
- "Run the BFSG/accessibility check for staging.example.ba, report in Bosnian."
- "Findings A11Y-001..A11Y-014 and PERF-* are approved, repo is …, go."

## Contents

```
skills/ywli-site-optimizer/
  SKILL.md                         the workflow
  scripts/
    package.json                   cheerio, puppeteer, @axe-core/puppeteer, lighthouse, googleapis
    crawl.mjs                      sitemap + link crawl → crawl.jsonl
    analyze-crawl.mjs              → urls.txt (indexable) + crawl-issues.json
    lh.mjs                         Lighthouse per URL, median of N runs → summary-<device>.csv
    axe.mjs                        axe WCAG 2.2 AA per URL → per-URL and per-rule JSON
    gsc.mjs                        Search Console page×query export (service account)
    render-pdf.mjs                 HTML → PDF (a4 report / 16:9 slides)
  templates/
    project.yml.example            per-client config
    env.example                    per-client secrets (never committed)
    ApplySeoChangesetTask.php      SS6 BuildTask: apply changeset to DRAFT, dry-run, rollback, conflict check
```

## Access a client has to provide

| When | What |
|---|---|
| Audit | URLs; staging basic auth; GSC (service account as *Restricted* user, or CSV export) |
| Fixes | repo access (branch + PR); CMS user with **Content Editor** role on staging |
| Only if no repo | SSH/SFTP (not plain FTP), read-only first |

Create dedicated accounts with minimal rights and revoke them after the project.

## Known limits

- Automated tools catch only part of all WCAG failures. The skill includes a manual WCAG 2.2 checklist per template.
- Local DDEV Performance scores are indicative only. Final numbers come from staging.
- Third-party scripts (GTM, cookie banners, embeds) can block the ≥90 target. They are reported as client decisions.
- Check the `ApplySeoChangesetTask` BuildTask signature against the installed `silverstripe/framework` 6.x before first use.

## Changelog

- **0.2.0** (2026-11-14): audit-only mode for sites with public HTTP access only; polite crawl (`YWLI_POLITE=1`); CMS/stack detection in crawl results.
- **0.1.0** (2026-11-14): initial version. WSL/DDEV workflow, scripts extracted from SKILL.md, crawl analysis, median Lighthouse, axe per-rule summary, GSC export, PDF rendering.
