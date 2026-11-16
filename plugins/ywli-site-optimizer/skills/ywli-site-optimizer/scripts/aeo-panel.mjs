#!/usr/bin/env node
// AI visibility panel: ask answer engines a fixed set of questions and record whether the site is cited
// and whether the brand is mentioned. Optional; costs money per question and provider.
// Usage: node aeo-panel.mjs <panel.json> <outDir>
//   panel.json: {"domain":"example.de","brand":["Muster GmbH","Muster"],"questions":["…", "…"]}
// Providers run only when their key is set:
//   PERPLEXITY_API_KEY  [PERPLEXITY_MODEL=sonar]
//   OPENAI_API_KEY      [OPENAI_MODEL=gpt-4.1]            [OPENAI_WEB_SEARCH_TOOL=web_search]
//   ANTHROPIC_API_KEY   [ANTHROPIC_MODEL=claude-sonnet-5-5] [ANTHROPIC_WEB_SEARCH_TOOL=web_search_20250305]
//   GEMINI_API_KEY      [GEMINI_MODEL=gemini-2.5-flash]
// Model and tool names change over time: if a provider errors, check its docs and override via env.
// Detection is response-shape agnostic: "cited" = the domain appears anywhere in the raw API response
// (citations, sources, grounding metadata); "mentioned" = a brand name appears in the answer text.
import { readFileSync, writeFileSync, appendFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const [, , panelFile, out] = process.argv;
if (!panelFile || !out) {
  console.error('Usage: node aeo-panel.mjs <panel.json> <outDir>');
  process.exit(1);
}
const panel = JSON.parse(readFileSync(panelFile, 'utf8'));
const domain = panel.domain.replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/\/.*$/, '').toLowerCase();
const brands = (panel.brand ?? []).map((b) => b.toLowerCase());
mkdirSync(out, { recursive: true });
const rawFile = join(out, 'aeo-panel.jsonl');
writeFileSync(rawFile, '');

const env = process.env;
const post = async (url, headers, body) => {
  const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) });
  const json = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${JSON.stringify(json).slice(0, 300)}`);
  return json;
};

const PROVIDERS = [
  {
    name: 'perplexity',
    enabled: Boolean(env.PERPLEXITY_API_KEY),
    ask: (q) => post('https://api.perplexity.ai/chat/completions',
      { Authorization: `Bearer ${env.PERPLEXITY_API_KEY}` },
      { model: env.PERPLEXITY_MODEL ?? 'sonar', messages: [{ role: 'user', content: q }] }),
  },
  {
    name: 'openai',
    enabled: Boolean(env.OPENAI_API_KEY),
    ask: (q) => post('https://api.openai.com/v1/responses',
      { Authorization: `Bearer ${env.OPENAI_API_KEY}` },
      { model: env.OPENAI_MODEL ?? 'gpt-4.1', input: q, tools: [{ type: env.OPENAI_WEB_SEARCH_TOOL ?? 'web_search' }] }),
  },
  {
    name: 'anthropic',
    enabled: Boolean(env.ANTHROPIC_API_KEY),
    ask: (q) => post('https://api.anthropic.com/v1/messages',
      { 'x-api-key': env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
      {
        model: env.ANTHROPIC_MODEL ?? 'claude-sonnet-5-5',
        max_tokens: 1024,
        messages: [{ role: 'user', content: q }],
        tools: [{ type: env.ANTHROPIC_WEB_SEARCH_TOOL ?? 'web_search_20250305', name: 'web_search', max_uses: 3 }],
      }),
  },
  {
    name: 'gemini',
    enabled: Boolean(env.GEMINI_API_KEY),
    ask: (q) => post(
      `https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_MODEL ?? 'gemini-2.5-flash'}:generateContent?key=${env.GEMINI_API_KEY}`,
      {},
      { contents: [{ parts: [{ text: q }] }], tools: [{ google_search: {} }] }),
  },
];

/** Collect answer text from any response shape: string values under text/content/output_text keys. */
function answerText(json) {
  const parts = [];
  const walk = (v, key) => {
    if (typeof v === 'string') { if (['text', 'content', 'output_text'].includes(key)) parts.push(v); return; }
    if (Array.isArray(v)) { v.forEach((x) => walk(x, key)); return; }
    if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) walk(x, k);
  };
  walk(json, '');
  return parts.join('\n');
}

const active = PROVIDERS.filter((p) => p.enabled);
if (!active.length) {
  console.error('No provider key set (PERPLEXITY_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY).');
  process.exit(1);
}

const summary = Object.fromEntries(active.map((p) => [p.name, { asked: 0, errors: 0, cited: 0, mentioned: 0 }]));
for (const q of panel.questions) {
  for (const p of active) {
    const s = summary[p.name];
    s.asked++;
    try {
      const json = await p.ask(q);
      const raw = JSON.stringify(json).toLowerCase();
      const text = answerText(json).toLowerCase();
      const cited = raw.includes(domain);
      const mentioned = brands.some((b) => text.includes(b));
      if (cited) s.cited++;
      if (mentioned) s.mentioned++;
      appendFileSync(rawFile, JSON.stringify({ provider: p.name, question: q, cited, mentioned, answer: answerText(json).slice(0, 4000) }) + '\n');
      console.log(`${p.name.padEnd(10)} cited:${cited ? 'Y' : '-'} mentioned:${mentioned ? 'Y' : '-'}  ${q}`);
    } catch (e) {
      s.errors++;
      appendFileSync(rawFile, JSON.stringify({ provider: p.name, question: q, error: String(e.message ?? e) }) + '\n');
      console.error(`${p.name.padEnd(10)} ERROR ${e.message ?? e}`);
    }
    await new Promise((r) => setTimeout(r, 1000));
  }
}
writeFileSync(join(out, 'aeo-panel-summary.json'), JSON.stringify({ domain, brands, questions: panel.questions.length, checked: new Date().toISOString(), summary }, null, 2));
console.log('\n' + Object.entries(summary).map(([k, v]) => `${k}: cited ${v.cited}/${v.asked - v.errors}, mentioned ${v.mentioned}/${v.asked - v.errors}, errors ${v.errors}`).join('\n'));
