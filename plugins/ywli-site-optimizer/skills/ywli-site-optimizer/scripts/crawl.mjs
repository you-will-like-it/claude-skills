#!/usr/bin/env node
// Crawl a site (sitemap + internal links) and emit one JSON record per URL.
// Usage: node crawl.mjs <startUrl> [maxPages=5000] > crawl.jsonl
// Env:   STAGING_BASIC_AUTH=user:pass   HTTP Basic auth for staging
//        YWLI_INSECURE=1                accept self-signed certs (local *.ddev.site only)
import * as cheerio from 'cheerio';

const [, , startArg, maxArg = '5000'] = process.argv;
if (!startArg) {
  console.error('Usage: node crawl.mjs <startUrl> [maxPages] > crawl.jsonl');
  process.exit(1);
}
if (process.env.YWLI_INSECURE === '1') process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const start = new URL(startArg);
const MAX = Number(maxArg);
const CONC = 4;
const headers = { 'User-Agent': 'Mozilla/5.0 (compatible; YWLI-Optimizer/0.1)' };
if (process.env.STAGING_BASIC_AUTH) {
  headers.Authorization = 'Basic ' + Buffer.from(process.env.STAGING_BASIC_AUTH).toString('base64');
}

const SKIP_EXT = /\.(pdf|jpe?g|png|gif|webp|avif|svg|ico|zip|rar|docx?|xlsx?|pptx?|mp4|webm|mp3|css|js|json|xml|txt|woff2?)$/i;
const seen = new Set();
const queue = [];
const inSitemap = new Set();

/** Normalize a URL relative to base; returns href for same-host http(s) pages, else null. */
function normalize(u, base = start) {
  try {
    const x = new URL(u, base);
    x.hash = '';
    if (x.host !== start.host || !/^https?:$/.test(x.protocol)) return null;
    if (SKIP_EXT.test(x.pathname)) return null;
    return x.href;
  } catch {
    return null;
  }
}

function enqueue(href) {
  if (href && !seen.has(href) && seen.size < MAX) {
    seen.add(href);
    queue.push(href);
  }
}

async function readSitemap(u, depth = 0) {
  if (depth > 3) return;
  try {
    const r = await fetch(u, { headers });
    if (!r.ok) return;
    const xml = await r.text();
    const locs = [...xml.matchAll(/<loc>\s*([^<\s]+)\s*<\/loc>/g)].map((m) => m[1].replace(/&amp;/g, '&'));
    for (const l of locs) {
      if (/\.xml(\?|$)/i.test(l)) {
        await readSitemap(l, depth + 1);
      } else {
        const n = normalize(l);
        if (n) {
          inSitemap.add(n);
          enqueue(n);
        }
      }
    }
  } catch {
    /* sitemap missing or unreachable: reported via analyze-crawl */
  }
}

async function visit(url) {
  const rec = { url, inSitemap: inSitemap.has(url) };
  const t0 = Date.now();
  try {
    const r = await fetch(url, { redirect: 'manual', headers });
    Object.assign(rec, {
      status: r.status,
      ms: Date.now() - t0,
      type: r.headers.get('content-type'),
      xRobots: r.headers.get('x-robots-tag'),
    });
    const loc = r.headers.get('location');
    if (r.status >= 300 && r.status < 400 && loc) {
      rec.location = new URL(loc, url).href;
      enqueue(normalize(rec.location));
      return rec;
    }
    if (!rec.type?.includes('text/html')) return rec;

    const $ = cheerio.load(await r.text());

    const jsonLdTypes = [];
    $('script[type="application/ld+json"]').each((_, e) => {
      try {
        const j = JSON.parse($(e).text());
        const nodes = [j, ...(Array.isArray(j) ? j : []), ...(j['@graph'] ?? [])].flat();
        for (const n of nodes) if (n && n['@type']) jsonLdTypes.push(...[n['@type']].flat());
      } catch {
        jsonLdTypes.push('INVALID_JSON');
      }
    });

    const outLinks = new Set();
    $('a[href]').each((_, e) => {
      const h = $(e).attr('href');
      if (!h || /^(mailto|tel|javascript|data):/i.test(h)) return;
      const n = normalize(h, url);
      if (n) {
        outLinks.add(n);
        enqueue(n);
      }
    });

    Object.assign(rec, {
      lang: $('html').attr('lang') ?? null,
      title: $('title').first().text().trim(),
      metaDescription: $('meta[name="description"]').attr('content')?.trim() ?? null,
      robots: $('meta[name="robots"]').attr('content') ?? null,
      canonical: $('link[rel="canonical"]').attr('href') ?? null,
      hreflang: $('link[rel="alternate"][hreflang]')
        .map((_, e) => ({ lang: $(e).attr('hreflang'), href: $(e).attr('href') }))
        .get(),
      h1: $('h1').map((_, e) => $(e).text().trim()).get(),
      headings: $('h1,h2,h3,h4,h5,h6').map((_, e) => e.name).get(),
      imgCount: $('img').length,
      imgNoAlt: $('img:not([alt])').length,
      imgNoDims: $('img').filter((_, e) => !$(e).attr('width') || !$(e).attr('height')).length,
      ogTitle: $('meta[property="og:title"]').attr('content') ?? null,
      ogImage: $('meta[property="og:image"]').attr('content') ?? null,
      jsonLdTypes,
      outLinks: [...outLinks],
    });

    $('script,style,noscript,template').remove();
    const main = $('main').length ? $('main') : $('body');
    rec.words = main.text().split(/\s+/).filter(Boolean).length;
  } catch (e) {
    rec.error = String(e?.cause?.code ?? e);
  }
  return rec;
}

await readSitemap(new URL('/sitemap.xml', start).href);
enqueue(normalize(start.href));

let i = 0;
let active = 0;
async function worker() {
  for (;;) {
    if (i < queue.length) {
      const u = queue[i++];
      active++;
      const rec = await visit(u);
      active--;
      process.stdout.write(JSON.stringify(rec) + '\n');
    } else if (active === 0) {
      return;
    } else {
      await new Promise((r) => setTimeout(r, 50));
    }
  }
}
await Promise.all(Array.from({ length: CONC }, worker));
