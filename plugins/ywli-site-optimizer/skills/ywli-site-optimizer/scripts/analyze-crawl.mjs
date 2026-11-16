#!/usr/bin/env node
// Turn crawl.jsonl into urls.txt (indexable HTML pages) and crawl-issues.json (SEO findings).
// Usage: node analyze-crawl.mjs <crawl.jsonl> <outDir> <startUrl>
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const [, , file, out, startArg] = process.argv;
if (!file || !out || !startArg) {
  console.error('Usage: node analyze-crawl.mjs <crawl.jsonl> <outDir> <startUrl>');
  process.exit(1);
}
mkdirSync(out, { recursive: true });

const recs = readFileSync(file, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l));
const byUrl = new Map(recs.map((r) => [r.url, r]));
const isHtml = (r) => r.status === 200 && r.type?.includes('text/html');
const noindex = (r) => /noindex/i.test(r.robots ?? '') || /noindex/i.test(r.xRobots ?? '');
const abs = (href, base) => {
  try { const u = new URL(href, base); u.hash = ''; return u.href; } catch { return null; }
};

const issues = [];
const add = (type, severity, urls, detail = undefined) => {
  const list = [urls].flat().filter(Boolean);
  if (list.length) issues.push({ type, severity, count: list.length, urls: list, ...(detail ? { detail } : {}) });
};

// Inbound links and click depth (BFS from start)
const inbound = new Map();
for (const r of recs) for (const l of r.outLinks ?? []) inbound.set(l, (inbound.get(l) ?? 0) + 1);
const start = abs(startArg, startArg);
const depth = new Map([[start, 0]]);
const bfs = [start];
while (bfs.length) {
  const u = bfs.shift();
  let r = byUrl.get(u);
  // follow redirects transparently for depth
  let hops = 0;
  while (r?.location && hops++ < 5) r = byUrl.get(r.location);
  for (const l of r?.outLinks ?? []) {
    if (!depth.has(l)) { depth.set(l, depth.get(u) + 1); bfs.push(l); }
  }
}

// Status / redirects
add('http-4xx', 'high', recs.filter((r) => r.status >= 400 && r.status < 500).map((r) => r.url));
add('http-5xx', 'critical', recs.filter((r) => r.status >= 500).map((r) => r.url));
add('fetch-error', 'high', recs.filter((r) => r.error).map((r) => `${r.url} (${r.error})`));
const chains = [];
for (const r of recs.filter((x) => x.location)) {
  let hops = 1;
  let cur = byUrl.get(r.location);
  while (cur?.location && hops < 10) { hops++; cur = byUrl.get(cur.location); }
  if (hops > 1) chains.push(`${r.url} (${hops} hops)`);
}
add('redirect-chain', 'medium', chains);

// Broken internal links: page -> target with 4xx/5xx
const broken = [];
for (const r of recs) for (const l of r.outLinks ?? []) {
  const t = byUrl.get(l);
  if (t && t.status >= 400) broken.push(`${r.url} -> ${l} [${t.status}]`);
}
add('broken-internal-link', 'high', broken);

const pages = recs.filter(isHtml);
const indexable = pages.filter((r) => !noindex(r) && (!r.canonical || abs(r.canonical, r.url) === r.url));

// Canonical / robots / lang / hreflang
add('canonical-missing', 'medium', pages.filter((r) => !r.canonical).map((r) => r.url));
add('canonical-to-other-url', 'low', pages.filter((r) => r.canonical && abs(r.canonical, r.url) !== r.url)
  .map((r) => `${r.url} -> ${r.canonical}`));
add('canonical-relative', 'low', pages.filter((r) => r.canonical && !/^https?:\/\//.test(r.canonical)).map((r) => r.url));
add('noindex', 'info', pages.filter(noindex).map((r) => r.url));
add('noindex-in-sitemap', 'high', pages.filter((r) => r.inSitemap && noindex(r)).map((r) => r.url));
add('html-lang-missing', 'high', pages.filter((r) => !r.lang).map((r) => r.url));
const hreflangBroken = [];
for (const r of pages) for (const h of r.hreflang ?? []) {
  const target = byUrl.get(abs(h.href, r.url));
  if (!target) continue;
  const back = (target.hreflang ?? []).some((x) => abs(x.href, target.url) === r.url);
  if (!back) hreflangBroken.push(`${r.url} -> ${h.lang} ${h.href} (no return link)`);
}
add('hreflang-not-reciprocal', 'medium', hreflangBroken);

// Titles / descriptions / headings
const dupes = (key) => {
  const m = new Map();
  for (const r of indexable) { const v = (r[key] ?? '').trim().toLowerCase(); if (v) m.set(v, [...(m.get(v) ?? []), r.url]); }
  return [...m.values()].filter((v) => v.length > 1).map((v) => v.join(' | '));
};
add('title-missing', 'high', indexable.filter((r) => !r.title).map((r) => r.url));
add('title-length', 'low', indexable.filter((r) => r.title && (r.title.length < 30 || r.title.length > 60))
  .map((r) => `${r.url} (${r.title.length})`));
add('title-duplicate', 'medium', dupes('title'));
add('meta-description-missing', 'medium', indexable.filter((r) => !r.metaDescription).map((r) => r.url));
add('meta-description-length', 'low', indexable.filter((r) => r.metaDescription &&
  (r.metaDescription.length < 70 || r.metaDescription.length > 160)).map((r) => `${r.url} (${r.metaDescription.length})`));
add('meta-description-duplicate', 'medium', dupes('metaDescription'));
add('h1-missing', 'high', indexable.filter((r) => !r.h1?.length).map((r) => r.url));
add('h1-multiple', 'medium', indexable.filter((r) => r.h1?.length > 1).map((r) => `${r.url} (${r.h1.length})`));
add('heading-level-skip', 'medium', indexable.filter((r) => {
  const lv = (r.headings ?? []).map((h) => Number(h[1]));
  return lv.some((l, i) => i > 0 && l > lv[i - 1] + 1);
}).map((r) => r.url));
add('thin-content', 'low', indexable.filter((r) => (r.words ?? 0) < 300).map((r) => `${r.url} (${r.words} words)`));

// Images / social / structured data
add('img-missing-alt', 'high', indexable.filter((r) => r.imgNoAlt > 0).map((r) => `${r.url} (${r.imgNoAlt})`));
add('img-missing-dimensions', 'medium', indexable.filter((r) => r.imgNoDims > 0).map((r) => `${r.url} (${r.imgNoDims})`));
add('og-missing', 'low', indexable.filter((r) => !r.ogTitle || !r.ogImage).map((r) => r.url));
add('jsonld-invalid', 'medium', indexable.filter((r) => r.jsonLdTypes?.includes('INVALID_JSON')).map((r) => r.url));
add('jsonld-missing', 'low', indexable.filter((r) => !r.jsonLdTypes?.length).map((r) => r.url));

// AEO / GEO (answer engines, AI search)
const A = (r) => r.aeo ?? {};
const anyOrg = pages.some((r) => A(r).orgSchema);
add('aeo-org-schema-missing', 'high', anyOrg ? [] : [start]);
add('aeo-org-sameas-missing', 'medium', anyOrg && !pages.some((r) => A(r).orgSameAs > 0) ? [start] : []);
add('aeo-no-date-modified', 'low', indexable.filter((r) => (r.words ?? 0) >= 300 && !A(r).dateModified).map((r) => r.url));
add('aeo-article-without-author', 'medium', indexable.filter((r) =>
  (r.jsonLdTypes ?? []).some((t) => /Article|BlogPosting|NewsArticle/.test(t)) && !A(r).hasAuthor).map((r) => r.url));
add('aeo-no-question-headings', 'low', indexable.filter((r) => (r.words ?? 0) >= 600 && !A(r).questionHeadings).map((r) => r.url));
add('aeo-question-without-direct-answer', 'medium', indexable.filter((r) => A(r).questionHeadings > A(r).questionsAnswered)
  .map((r) => `${r.url} (${A(r).questionHeadings - A(r).questionsAnswered}/${A(r).questionHeadings})`));
add('aeo-long-page-unstructured', 'low', indexable.filter((r) => (r.words ?? 0) >= 800 && !A(r).lists && !A(r).tables)
  .map((r) => `${r.url} (${r.words} words)`));

// Architecture
add('sitemap-empty-or-missing', 'high', recs.some((r) => r.inSitemap) ? [] : [new URL('/sitemap.xml', startArg).href]);
add('not-in-sitemap', 'low', indexable.filter((r) => !r.inSitemap).map((r) => r.url));
add('orphan-in-sitemap', 'medium', indexable.filter((r) => r.inSitemap && !inbound.get(r.url) && r.url !== start).map((r) => r.url));
add('click-depth-gt-3', 'low', indexable.filter((r) => (depth.get(r.url) ?? 99) > 3)
  .map((r) => `${r.url} (${depth.has(r.url) ? depth.get(r.url) : 'unreachable'})`));
add('slow-ttfb-gt-800ms', 'medium', pages.filter((r) => r.ms > 800).map((r) => `${r.url} (${r.ms}ms)`));

const order = { critical: 0, high: 1, medium: 2, low: 3, info: 4 };
issues.sort((a, b) => order[a.severity] - order[b.severity] || b.count - a.count);

writeFileSync(join(out, 'urls.txt'), indexable.map((r) => r.url).join('\n') + '\n');
const stackCount = new Map();
for (const r of pages) for (const s of r.stack ?? []) stackCount.set(s, (stackCount.get(s) ?? 0) + 1);
const stack = [...stackCount].sort((a, b) => b[1] - a[1]).map(([hint, pages]) => ({ hint, pages }));

writeFileSync(join(out, 'crawl-issues.json'), JSON.stringify({
  crawled: recs.length, htmlPages: pages.length, indexable: indexable.length, stack, issues,
}, null, 2));
console.log(`stack: ${stack.map((s) => s.hint).join(', ') || 'unknown'}`);
console.log(`crawled=${recs.length} html=${pages.length} indexable=${indexable.length} issueTypes=${issues.length}`);
for (const i of issues) console.log(`${i.severity.padEnd(8)} ${i.type.padEnd(28)} ${i.count}`);
