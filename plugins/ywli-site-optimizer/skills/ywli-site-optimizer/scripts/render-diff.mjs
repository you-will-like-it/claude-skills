#!/usr/bin/env node
// Compare raw HTML (what most AI crawlers see, no JavaScript) with the rendered DOM (what a browser sees).
// Usage: node render-diff.mjs <urls.txt> <out.json>
// Env:   STAGING_BASIC_AUTH=user:pass, YWLI_INSECURE=1 (local *.ddev.site only)
import * as cheerio from 'cheerio';
import puppeteer from 'puppeteer';
import { readFileSync, writeFileSync } from 'node:fs';

const [, , list, outFile] = process.argv;
if (!list || !outFile) {
  console.error('Usage: node render-diff.mjs <urls.txt> <out.json>');
  process.exit(1);
}
if (process.env.YWLI_INSECURE === '1') process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const headers = { 'User-Agent': 'Mozilla/5.0 (compatible; YWLI-Optimizer/0.4)' };
if (process.env.STAGING_BASIC_AUTH) {
  headers.Authorization = 'Basic ' + Buffer.from(process.env.STAGING_BASIC_AUTH).toString('base64');
}
const words = (t) => (t ?? '').split(/\s+/).filter(Boolean).length;

const args = ['--no-sandbox', '--disable-dev-shm-usage'];
if (process.env.YWLI_INSECURE === '1') args.push('--ignore-certificate-errors');
const browser = await puppeteer.launch({ headless: true, args });

const urls = readFileSync(list, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
const results = [];
for (const url of urls) {
  const rec = { url };
  try {
    const r = await fetch(url, { headers });
    const $ = cheerio.load(await r.text());
    rec.rawH1 = $('h1').length;
    $('script,style,noscript,template').remove();
    rec.rawWords = words($('body').text());

    const page = await browser.newPage();
    if (process.env.STAGING_BASIC_AUTH) {
      const [username, ...rest] = process.env.STAGING_BASIC_AUTH.split(':');
      await page.authenticate({ username, password: rest.join(':') });
    }
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 60000 });
    const rendered = await page.evaluate(() => ({
      text: document.body?.innerText ?? '',
      h1: document.querySelectorAll('h1').length,
    }));
    await page.close();
    rec.renderedWords = words(rendered.text);
    rec.renderedH1 = rendered.h1;
    rec.ratio = rec.rawWords ? Number((rec.renderedWords / rec.rawWords).toFixed(2)) : null;
    // JS-dependent: substantially more text after rendering, or the H1 only exists after rendering
    rec.jsDependent = (rec.renderedWords > rec.rawWords * 1.5 + 50) || (rec.rawH1 === 0 && rec.renderedH1 > 0);
  } catch (e) {
    rec.error = String(e.message ?? e);
  }
  results.push(rec);
  console.log(`${rec.error ? 'ERROR' : rec.jsDependent ? 'JS-DEPENDENT' : 'ok'}  raw=${rec.rawWords ?? '-'} rendered=${rec.renderedWords ?? '-'}  ${url}`);
}
await browser.close();
writeFileSync(outFile, JSON.stringify(results, null, 2));
