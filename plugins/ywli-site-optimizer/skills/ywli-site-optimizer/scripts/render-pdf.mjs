#!/usr/bin/env node
// Render a self-contained HTML report to PDF with headless Chrome.
// Usage: node render-pdf.mjs <in.html> <out.pdf> [a4|slides]
//   a4     detailed technical report, page numbers + "powered by YouWillLikeIT" footer
//   slides 16:9 presentation, one <section class="slide"> per page (1280x720 CSS px)
import puppeteer from 'puppeteer';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [, , html, pdf, mode = 'a4'] = process.argv;
if (!html || !pdf || !['a4', 'slides'].includes(mode)) {
  console.error('Usage: node render-pdf.mjs <in.html> <out.pdf> [a4|slides]');
  process.exit(1);
}

const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage'] });
const page = await browser.newPage();
await page.goto(pathToFileURL(resolve(html)).href, { waitUntil: 'networkidle0' });
await page.evaluate(() => document.fonts.ready);

if (mode === 'slides') {
  await page.pdf({ path: pdf, width: '1280px', height: '720px', printBackground: true });
} else {
  await page.pdf({
    path: pdf,
    format: 'A4',
    printBackground: true,
    margin: { top: '18mm', bottom: '20mm', left: '16mm', right: '16mm' },
    displayHeaderFooter: true,
    headerTemplate: '<span></span>',
    footerTemplate:
      '<div style="font-size:8px;width:100%;padding:0 16mm;display:flex;justify-content:space-between;color:#555">' +
      '<span>powered by YouWillLikeIT</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>',
  });
}
await browser.close();
console.log(`PDF written: ${pdf}`);
