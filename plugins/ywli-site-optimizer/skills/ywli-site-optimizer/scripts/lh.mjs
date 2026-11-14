#!/usr/bin/env node
// Run Lighthouse sequentially over a URL list and write a summary CSV (median of N runs per URL).
// Usage: node lh.mjs <urls.txt> <mobile|desktop> <outDir> [runs=1]
// Env:   CHROME_PATH                    Chrome binary (e.g. puppeteer's Chrome in WSL)
//        STAGING_BASIC_AUTH=user:pass   HTTP Basic auth
//        YWLI_INSECURE=1                ignore certificate errors (local *.ddev.site only)
// Sequential on purpose: parallel runs skew Performance scores.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, appendFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const [, , list, device, out, runsArg = '1'] = process.argv;
if (!list || !['mobile', 'desktop'].includes(device) || !out) {
  console.error('Usage: node lh.mjs <urls.txt> <mobile|desktop> <outDir> [runs=1]');
  process.exit(1);
}
const RUNS = Math.max(1, Number(runsArg));
const bin = join(dirname(fileURLToPath(import.meta.url)), 'node_modules/.bin/lighthouse');
mkdirSync(join(out, 'json'), { recursive: true });

const csv = join(out, `summary-${device}.csv`);
if (!existsSync(csv)) {
  writeFileSync(csv, 'url,device,runs,performance,accessibility,best_practices,seo,lcp_ms,cls,tbt_ms,fcp_ms,report\n');
}

const chromeFlags = ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage'];
if (process.env.YWLI_INSECURE === '1') chromeFlags.push('--ignore-certificate-errors');
const extra = process.env.STAGING_BASIC_AUTH
  ? ['--extra-headers', JSON.stringify({ Authorization: 'Basic ' + Buffer.from(process.env.STAGING_BASIC_AUTH).toString('base64') })]
  : [];

const median = (xs) => {
  const s = xs.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  if (!s.length) return NaN;
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

const urls = readFileSync(list, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
let n = 0;
for (const url of urls) {
  n++;
  const id = createHash('md5').update(url).digest('hex').slice(0, 12);
  const runs = [];
  for (let k = 1; k <= RUNS; k++) {
    const file = join(out, 'json', `${device}-${id}-r${k}-${Date.now()}.json`);
    try {
      execFileSync(bin, [
        url, '--quiet', '--output=json', `--output-path=${file}`,
        '--only-categories=performance,accessibility,best-practices,seo',
        `--chrome-flags=${chromeFlags.join(' ')}`,
        ...(device === 'desktop' ? ['--preset=desktop'] : []),
        ...extra,
      ], { stdio: 'ignore', timeout: 180000 });
      const r = JSON.parse(readFileSync(file, 'utf8'));
      const c = r.categories;
      const a = r.audits;
      runs.push({
        file,
        performance: (c.performance?.score ?? NaN) * 100,
        accessibility: (c.accessibility?.score ?? NaN) * 100,
        best_practices: (c['best-practices']?.score ?? NaN) * 100,
        seo: (c.seo?.score ?? NaN) * 100,
        lcp: a['largest-contentful-paint']?.numericValue,
        cls: a['cumulative-layout-shift']?.numericValue,
        tbt: a['total-blocking-time']?.numericValue,
        fcp: a['first-contentful-paint']?.numericValue,
      });
    } catch (e) {
      console.error(`[${n}/${urls.length}] ${device} run ${k} failed: ${url} (${e.code ?? e.message})`);
    }
  }
  if (!runs.length) {
    appendFileSync(csv, `${JSON.stringify(url)},${device},0,ERROR,,,,,,,,\n`);
    continue;
  }
  const med = (k) => median(runs.map((r) => r[k]));
  const perf = med('performance');
  // keep the report closest to the median Performance score for later inspection
  const rep = runs.reduce((best, r) => (Math.abs(r.performance - perf) < Math.abs(best.performance - perf) ? r : best));
  appendFileSync(csv, [
    JSON.stringify(url), device, runs.length,
    Math.round(perf), Math.round(med('accessibility')), Math.round(med('best_practices')), Math.round(med('seo')),
    Math.round(med('lcp')), med('cls').toFixed(3), Math.round(med('tbt')), Math.round(med('fcp')),
    JSON.stringify(rep.file),
  ].join(',') + '\n');
  console.log(`[${n}/${urls.length}] ${device} P${Math.round(perf)} A${Math.round(med('accessibility'))} BP${Math.round(med('best_practices'))} S${Math.round(med('seo'))} ${url}`);
}
