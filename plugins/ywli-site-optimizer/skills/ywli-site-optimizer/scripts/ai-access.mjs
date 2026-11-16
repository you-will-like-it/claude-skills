#!/usr/bin/env node
// AI crawler access check: robots.txt rules per AI bot, WAF/CDN response per bot user agent, llms.txt presence.
// Usage: node ai-access.mjs <siteUrl> <out.json> [urls.txt]
//   urls.txt (optional): sample URLs whose paths are also evaluated against robots.txt (first 20 used)
// Env:   STAGING_BASIC_AUTH=user:pass, YWLI_INSECURE=1 (local *.ddev.site only)
//
// Notes
// - robots.txt matching follows RFC 9309: groups matched by product token (case-insensitive), longest path match wins,
//   Allow wins a tie, "*" and "$" supported.
// - The WAF probe sends a request with the bot's token in the User-Agent from THIS machine's IP. Real bots come from
//   their vendors' IP ranges, and some WAFs verify that, so probe results are indicative, not proof.
// - Google-Extended and Applebot-Extended are robots.txt control tokens only; they are never probed.
import { readFileSync, writeFileSync } from 'node:fs';

const [, , siteArg, outFile, urlsFile] = process.argv;
if (!siteArg || !outFile) {
  console.error('Usage: node ai-access.mjs <siteUrl> <out.json> [urls.txt]');
  process.exit(1);
}
if (process.env.YWLI_INSECURE === '1') process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const site = new URL(siteArg);
const baseHeaders = {};
if (process.env.STAGING_BASIC_AUTH) {
  baseHeaders.Authorization = 'Basic ' + Buffer.from(process.env.STAGING_BASIC_AUTH).toString('base64');
}

// role: search = builds the index AI answers cite from; user = fetches a page when a person asks;
//       training = collects model training data; token = robots.txt control token only (no crawler)
const BOTS = [
  { token: 'OAI-SearchBot', vendor: 'OpenAI', role: 'search' },
  { token: 'ChatGPT-User', vendor: 'OpenAI', role: 'user' },
  { token: 'GPTBot', vendor: 'OpenAI', role: 'training' },
  { token: 'Claude-SearchBot', vendor: 'Anthropic', role: 'search' },
  { token: 'Claude-User', vendor: 'Anthropic', role: 'user' },
  { token: 'ClaudeBot', vendor: 'Anthropic', role: 'training' },
  { token: 'PerplexityBot', vendor: 'Perplexity', role: 'search' },
  { token: 'Perplexity-User', vendor: 'Perplexity', role: 'user' },
  { token: 'Googlebot', vendor: 'Google', role: 'search', note: 'Google Search incl. AI Overviews / AI Mode' },
  { token: 'Google-Extended', vendor: 'Google', role: 'token', note: 'Gemini training/grounding control; not a crawler' },
  { token: 'Bingbot', vendor: 'Microsoft', role: 'search', note: 'Bing index, used by Copilot' },
  { token: 'Applebot', vendor: 'Apple', role: 'search' },
  { token: 'Applebot-Extended', vendor: 'Apple', role: 'token', note: 'Apple AI training control; not a crawler' },
  { token: 'meta-externalagent', vendor: 'Meta', role: 'training' },
  { token: 'CCBot', vendor: 'Common Crawl', role: 'training' },
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function get(url, ua) {
  try {
    const r = await fetch(url, { headers: { ...baseHeaders, 'User-Agent': ua }, redirect: 'follow' });
    const text = await r.text();
    return { status: r.status, type: r.headers.get('content-type'), text, server: r.headers.get('server') };
  } catch (e) {
    return { status: 0, error: String(e?.cause?.code ?? e), text: '' };
  }
}

function parseRobots(txt) {
  const groups = [];
  let cur = null;
  let lastWasAgent = false;
  const sitemaps = [];
  for (const raw of txt.split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, '').trim();
    if (!line) continue;
    const m = line.match(/^([A-Za-z-]+)\s*:\s*(.*)$/);
    if (!m) continue;
    const key = m[1].toLowerCase();
    const val = m[2].trim();
    if (key === 'user-agent') {
      if (!cur || !lastWasAgent) {
        cur = { agents: [], rules: [] };
        groups.push(cur);
      }
      cur.agents.push(val.toLowerCase());
      lastWasAgent = true;
      continue;
    }
    lastWasAgent = false;
    if (key === 'sitemap') sitemaps.push(val);
    else if (cur && (key === 'allow' || key === 'disallow')) cur.rules.push({ allow: key === 'allow', path: val });
  }
  return { groups, sitemaps };
}

function rulesFor(groups, token) {
  const t = token.toLowerCase();
  const specific = groups.filter((g) => g.agents.includes(t));
  if (specific.length) return { group: token, rules: specific.flatMap((g) => g.rules) };
  const star = groups.filter((g) => g.agents.includes('*'));
  return { group: star.length ? '*' : null, rules: star.flatMap((g) => g.rules) };
}

function ruleMatches(pattern, path) {
  const anchored = pattern.endsWith('$');
  const body = anchored ? pattern.slice(0, -1) : pattern;
  const re = '^' + body.split('*').map((s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*') + (anchored ? '$' : '');
  return new RegExp(re).test(path);
}

function isAllowed(rules, path) {
  let best = null;
  for (const r of rules) {
    if (!r.path) continue; // empty Disallow = no restriction
    if (!ruleMatches(r.path, path)) continue;
    if (!best || r.path.length > best.path.length || (r.path.length === best.path.length && r.allow)) best = r;
  }
  return best ? best.allow : true;
}

function looksLikeChallenge(res) {
  if ([401, 403, 406, 429, 503].includes(res.status)) return true;
  return /cf-chl|challenge-platform|just a moment|attention required|captcha|access denied|bot protection/i.test(res.text.slice(0, 20000));
}

// --- robots.txt
const robotsUrl = new URL('/robots.txt', site).href;
const robotsRes = await get(robotsUrl, 'Mozilla/5.0 (compatible; YWLI-Optimizer/0.4)');
const robotsOk = robotsRes.status === 200 && !/text\/html/i.test(robotsRes.type ?? '');
const { groups, sitemaps } = robotsOk ? parseRobots(robotsRes.text) : { groups: [], sitemaps: [] };

const samplePaths = ['/'];
if (urlsFile) {
  for (const u of readFileSync(urlsFile, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean).slice(0, 20)) {
    try {
      const x = new URL(u);
      if (x.host === site.host) samplePaths.push(x.pathname + x.search);
    } catch { /* ignore */ }
  }
}
const paths = [...new Set(samplePaths)];

// --- baseline (normal browser UA) for WAF comparison
const browserUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36';
const baseline = await get(site.href, browserUA);

const bots = [];
for (const b of BOTS) {
  const { group, rules } = rulesFor(groups, b.token);
  const blockedPaths = paths.filter((p) => !isAllowed(rules, p));
  const entry = {
    ...b,
    robotsGroup: group,
    robotsHomeAllowed: isAllowed(rules, '/'),
    robotsBlockedSamplePaths: blockedPaths,
  };
  if (b.role !== 'token') {
    await sleep(500);
    const res = await get(site.href, `Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; ${b.token}/1.0)`);
    entry.probeStatus = res.status;
    entry.probeChallenged = res.status === 0 ? null : looksLikeChallenge(res) && !looksLikeChallenge(baseline);
  }
  bots.push(entry);
}

// --- llms.txt (optional proposal standard; informational only)
const llms = await get(new URL('/llms.txt', site).href, browserUA);
const llmsTxt = {
  present: llms.status === 200 && !/text\/html/i.test(llms.type ?? ''),
  status: llms.status,
  bytes: llms.text.length,
};

// --- findings
const issues = [];
const push = (type, severity, detail) => issues.push({ type, severity, detail });
if (!robotsOk) push('robots-missing-or-html', 'medium', `${robotsUrl} -> ${robotsRes.status} ${robotsRes.type ?? ''}`);
for (const b of bots) {
  if (b.role === 'search' && !b.robotsHomeAllowed) push('ai-search-bot-blocked-robots', 'high', `${b.token} (${b.vendor}) blocked by robots.txt group "${b.robotsGroup}"`);
  if (b.role === 'search' && b.robotsHomeAllowed && b.robotsBlockedSamplePaths.length) {
    push('ai-search-bot-partially-blocked', 'medium', `${b.token}: ${b.robotsBlockedSamplePaths.length} sample paths disallowed`);
  }
  if (b.role === 'user' && !b.robotsHomeAllowed) push('ai-user-fetcher-blocked-robots', 'medium', `${b.token} (${b.vendor}) blocked by robots.txt`);
  if ((b.role === 'search' || b.role === 'user') && b.probeChallenged) {
    push('ai-bot-blocked-by-waf', 'high', `${b.token}: HTTP ${b.probeStatus} / challenge page (baseline ${baseline.status}); verify in CDN/WAF bot settings`);
  }
  if (b.role === 'training' || b.role === 'token') {
    push('ai-training-policy', 'info', `${b.token}: ${b.robotsHomeAllowed ? 'allowed' : 'blocked'} (client decision)`);
  }
}

const result = {
  site: site.href,
  checked: new Date().toISOString(),
  robots: { url: robotsUrl, status: robotsRes.status, valid: robotsOk, groups: groups.length, sitemaps },
  baseline: { status: baseline.status, challenged: baseline.status ? looksLikeChallenge(baseline) : null },
  bots,
  llmsTxt,
  issues,
};
writeFileSync(outFile, JSON.stringify(result, null, 2));

console.log(`robots.txt: ${robotsRes.status}${robotsOk ? '' : ' (missing/invalid)'}  baseline: ${baseline.status}  llms.txt: ${llmsTxt.present ? 'present' : 'absent'}`);
for (const b of bots) {
  const probe = b.role === 'token' ? 'token only' : `probe ${b.probeStatus}${b.probeChallenged ? ' CHALLENGED' : ''}`;
  console.log(`${b.role.padEnd(8)} ${b.token.padEnd(19)} robots:${b.robotsHomeAllowed ? 'allow' : 'BLOCK'} (${b.robotsGroup ?? 'none'})  ${probe}`);
}
for (const i of issues.filter((x) => x.severity !== 'info')) console.log(`${i.severity.padEnd(7)} ${i.type}: ${i.detail}`);
