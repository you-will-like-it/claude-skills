#!/usr/bin/env node
// Run axe-core (WCAG 2.0/2.1/2.2 A+AA + best practices) over a URL list.
// Usage: node axe.mjs <urls.txt> <outDir> [viewportWidth=1366]
// Env:   STAGING_BASIC_AUTH=user:pass   HTTP Basic auth
//        YWLI_INSECURE=1                ignore certificate errors (local *.ddev.site only)
import puppeteer from 'puppeteer';
import { AxePuppeteer } from '@axe-core/puppeteer';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const [, , list, out, widthArg = '1366'] = process.argv;
if (!list || !out) {
  console.error('Usage: node axe.mjs <urls.txt> <outDir> [viewportWidth]');
  process.exit(1);
}
const width = Number(widthArg);
mkdirSync(out, { recursive: true });

const args = ['--no-sandbox', '--disable-dev-shm-usage'];
if (process.env.YWLI_INSECURE === '1') args.push('--ignore-certificate-errors');
const browser = await puppeteer.launch({ headless: true, args });

const TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];
const urls = readFileSync(list, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
const results = [];
let n = 0;
for (const url of urls) {
  n++;
  const page = await browser.newPage();
  try {
    if (process.env.STAGING_BASIC_AUTH) {
      const [username, ...rest] = process.env.STAGING_BASIC_AUTH.split(':');
      await page.authenticate({ username, password: rest.join(':') });
    }
    await page.setViewport({ width, height: 900 });
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 60000 });
    const r = await new AxePuppeteer(page).withTags(TAGS).analyze();
    const violations = r.violations.map((v) => ({
      id: v.id,
      impact: v.impact,
      wcag: v.tags.filter((t) => /^wcag\d{3,}$/.test(t)),
      help: v.help,
      helpUrl: v.helpUrl,
      count: v.nodes.length,
      nodes: v.nodes.slice(0, 20).map((x) => ({ target: x.target.join(' '), html: x.html.slice(0, 300), summary: x.failureSummary })),
    }));
    results.push({ url, width, violations, incomplete: r.incomplete.map((v) => ({ id: v.id, count: v.nodes.length })) });
    const serious = violations.filter((v) => ['critical', 'serious'].includes(v.impact)).length;
    console.log(`[${n}/${urls.length}] ${violations.length} rules violated (${serious} critical/serious) ${url}`);
  } catch (e) {
    results.push({ url, width, error: String(e.message ?? e) });
    console.error(`[${n}/${urls.length}] ERROR ${url}: ${e.message ?? e}`);
  } finally {
    await page.close();
  }
}
await browser.close();

// Aggregate per rule across all URLs (fix by template, not by URL)
const byRule = new Map();
for (const p of results) for (const v of p.violations ?? []) {
  const agg = byRule.get(v.id) ?? { id: v.id, impact: v.impact, wcag: v.wcag, help: v.help, helpUrl: v.helpUrl, pages: 0, nodes: 0, sampleUrls: [] };
  agg.pages++;
  agg.nodes += v.count;
  if (agg.sampleUrls.length < 10) agg.sampleUrls.push(p.url);
  byRule.set(v.id, agg);
}
const impactOrder = { critical: 0, serious: 1, moderate: 2, minor: 3 };
const summary = [...byRule.values()].sort((a, b) => impactOrder[a.impact] - impactOrder[b.impact] || b.pages - a.pages);

writeFileSync(join(out, `axe-${width}.json`), JSON.stringify(results, null, 2));
writeFileSync(join(out, `axe-${width}-summary.json`), JSON.stringify(summary, null, 2));
console.log(`\nrules violated: ${summary.length}`);
for (const s of summary) console.log(`${(s.impact ?? '').padEnd(9)} ${s.id.padEnd(32)} pages=${s.pages} nodes=${s.nodes}`);
