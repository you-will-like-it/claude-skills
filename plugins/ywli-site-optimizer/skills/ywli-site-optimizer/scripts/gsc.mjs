#!/usr/bin/env node
// Export Google Search Console Performance data (page x query) via a service account.
// Usage: node gsc.mjs <siteUrl> <outFile.jsonl> [months=16]
//   siteUrl: "sc-domain:example.de" or "https://www.example.de/"
// Env:     GSC_SA_KEY=/abs/path/service-account.json
//          (the service account e-mail must be added as a user in GSC, "Restricted" is enough)
import { google } from 'googleapis';
import { createWriteStream } from 'node:fs';

const [, , siteUrl, outFile, monthsArg = '16'] = process.argv;
if (!siteUrl || !outFile || !process.env.GSC_SA_KEY) {
  console.error('Usage: GSC_SA_KEY=key.json node gsc.mjs <siteUrl> <outFile.jsonl> [months]');
  process.exit(1);
}

const auth = new google.auth.GoogleAuth({
  keyFile: process.env.GSC_SA_KEY,
  scopes: ['https://www.googleapis.com/auth/webmasters.readonly'],
});
const sc = google.searchconsole({ version: 'v1', auth });

const fmt = (d) => d.toISOString().slice(0, 10);
const end = new Date();
end.setDate(end.getDate() - 3); // GSC data lags ~2-3 days
const start = new Date(end);
start.setMonth(start.getMonth() - Number(monthsArg));

const out = createWriteStream(outFile);
const ROW_LIMIT = 25000;
let startRow = 0;
let total = 0;
for (;;) {
  const res = await sc.searchanalytics.query({
    siteUrl,
    requestBody: {
      startDate: fmt(start),
      endDate: fmt(end),
      dimensions: ['page', 'query'],
      rowLimit: ROW_LIMIT,
      startRow,
    },
  });
  const rows = res.data.rows ?? [];
  for (const r of rows) {
    out.write(JSON.stringify({
      page: r.keys[0], query: r.keys[1], clicks: r.clicks, impressions: r.impressions,
      ctr: Number(r.ctr.toFixed(4)), position: Number(r.position.toFixed(1)),
    }) + '\n');
  }
  total += rows.length;
  if (rows.length < ROW_LIMIT) break;
  startRow += ROW_LIMIT;
}
out.end();
console.log(`${total} rows ${fmt(start)}..${fmt(end)} -> ${outFile}`);
