'use strict';
// AccessDeck - Codex Plus 额度智能调度器
// 核心语义：最小请求仅用于尝试在空闲期启动五小时窗口，绝不保证或强制刷新/重置额度。

const fs = require('node:fs');
const http = require('node:http');
const { execFileSync } = require('node:child_process');

const DIR = process.env.CPA_SCHEDULER_DIR || '/root/CLIProxyAPI/plus-scheduler';
const STATE = DIR + '/state.json';
const CONFIG = DIR + '/config.json';
const DAY = 86400000;
const HALF_HOUR = 1800000;

function localDate(ms) {
  return new Date(ms + 8 * 3600000).toISOString().slice(0, 10);
}

function minute(ms) {
  const d = new Date(ms + 8 * 3600000);
  return d.getUTCHours() * 60 + d.getUTCMinutes();
}

function at(date, time) {
  return Date.parse(date + 'T' + time + ':00+08:00');
}

function log(event, details = {}) {
  console.log(JSON.stringify({ time: new Date().toISOString(), event, ...details }));
}

function save(state) {
  fs.writeFileSync(STATE + '.tmp', JSON.stringify(state), { mode: 0o600 });
  fs.renameSync(STATE + '.tmp', STATE);
}

function load() {
  if (!fs.existsSync(STATE)) {
    return { samples: [], attempts: [], planning: [], plan: null };
  }
  return JSON.parse(fs.readFileSync(STATE, 'utf8'));
}

function windowData(w) {
  if (!w || !Number.isFinite(w.used_percent) || w.used_percent < 0 || w.used_percent > 100 || !Number.isFinite(w.reset_at)) {
    throw new Error('Invalid quota window');
  }
  return { used: w.used_percent, reset: w.reset_at * 1000, seconds: w.limit_window_seconds };
}

function summarize(samples, now) {
  const recent = samples.filter(s => s.time >= now - 7 * DAY);
  const slots = Array.from({ length: 48 }, (_, i) => ({
    time: String(Math.floor(i / 2)).padStart(2, '0') + ':' + (i % 2 ? '30' : '00'),
    accounts: {}
  }));
  const last = new Map();
  const intervals = [];
  for (const s of recent) {
    if (!s.quota) {
      last.delete(s.account);
      continue;
    }
    const p = last.get(s.account);
    last.set(s.account, s);
    if (!p || s.time - p.time > 45 * 60000 || s.time <= p.time) continue;

    // 跨 reset 时，仅统计新窗口中当前可见的实际消耗
    const same = s.quota.primary.reset === p.quota.primary.reset;
    const used = same ? s.quota.primary.used - p.quota.primary.used : s.quota.primary.used;
    if (used < 0) continue;

    const slot = slots[Math.floor(minute(p.time) / 30)];
    const agg = slot.accounts[s.account] ||= { observed: 0, consumedPercent: 0, resetIntervals: 0 };
    agg.observed++;
    agg.consumedPercent += used;
    if (!same) agg.resetIntervals++;

    if (s.time >= now - DAY) {
      intervals.push({
        account: s.account,
        from: p.time,
        to: s.time,
        consumedPercent: used,
        crossedReset: !same
      });
    }
  }

  return {
    timezone: 'Asia/Shanghai',
    sevenDaySlots: slots,
    last24Hours: intervals,
    validSamples: recent.filter(s => s.quota).length,
    historyHours: recent.length ? (now - recent[0].time) / 3600000 : 0
  };
}

function validatePlan(raw, date, ids) {
  if (!raw || raw.date !== date || !Array.isArray(raw.accounts) || raw.accounts.length !== ids.length) {
    throw new Error('Invalid plan date/accounts');
  }
  const seen = new Set();
  for (const a of raw.accounts) {
    if (!ids.includes(a.account) || seen.has(a.account) || !Array.isArray(a.times) || a.times.length > 3 || typeof a.reason !== 'string' || a.reason.length > 1500) {
      throw new Error('Invalid account plan');
    }
    seen.add(a.account);
    let prev = -Infinity;
    for (const t of a.times) {
      if (typeof t !== 'string' || !/^(?:[01]\d|2[0-3]):(?:00|30)$/.test(t)) {
        throw new Error('Invalid plan time');
      }
      const ts = at(date, t);
      if (ts - prev < 4 * 3600000) {
        throw new Error('Plan times must be sorted and four hours apart');
      }
      prev = ts;
    }
  }
  return raw;
}

function activationDecision(state, account, sample, now) {
  if (!sample?.quota || now - sample.time > 10 * 60000) return 'quota-unavailable';
  const q = sample.quota;
  if (!q.allowed || q.primary.used >= 100 || q.weekly.used >= 100) return 'quota-exhausted';
  if (q.primary.used > 0 && q.primary.reset > now) return 'window-already-active';

  const today = state.attempts.filter(a => a.account === account && a.status !== 'skipped' && localDate(a.time) === localDate(now));
  if (today.length >= 3) return 'daily-cap';

  if (state.attempts.some(a => a.account === account && a.status !== 'skipped' && now - a.time < 4 * 3600000)) {
    return 'minimum-interval';
  }

  return null;
}

function getCredentialsEnv() {
  if (process.env.CPA_BASE_URL && process.env.CPA_MANAGEMENT_KEY) {
    return {
      CPA_BASE_URL: process.env.CPA_BASE_URL,
      CPA_MANAGEMENT_KEY: process.env.CPA_MANAGEMENT_KEY
    };
  }
  try {
    const container = JSON.parse(execFileSync('docker', ['inspect', 'cpa-usage-keeper'], { encoding: 'utf8' }))[0];
    const env = Object.fromEntries(container.Config.Env.map(line => {
      const n = line.indexOf('=');
      return [line.slice(0, n), line.slice(n + 1)];
    }));
    if (env.CPA_BASE_URL && env.CPA_MANAGEMENT_KEY) {
      return env;
    }
  } catch {
    // ignore
  }
  throw new Error('Keeper management configuration missing');
}

async function connect() {
  const env = getCredentialsEnv();
  const base = env.CPA_BASE_URL.replace(/\/$/, '');

  async function request(url, key, body) {
    const response = await fetch(url, {
      method: body ? 'POST' : 'GET',
      headers: {
        Authorization: 'Bearer ' + key,
        'Content-Type': 'application/json'
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(120000)
    });
    if (!response.ok) throw new Error('HTTP ' + response.status);
    return response.json();
  }

  const call = (path, body) => request(base + '/v8/management' + path, env.CPA_MANAGEMENT_KEY, body);
  const { files } = await call('/credentials');
  const accounts = files.filter(f => f.provider === 'codex' && !f.disabled && f.id_token?.plan_type === 'plus');
  if (accounts.length !== 2 || accounts.some(a => !a.auth_index || !a.id_token?.chatgpt_account_id)) {
    throw new Error('Expected two enabled Plus credentials with identities');
  }

  async function upstream(a, method, url, payload) {
    const result = await call('/requests/api-call', {
      auth_index: a.auth_index,
      method,
      url,
      header: {
        Authorization: 'Bearer $TOKEN$',
        'Chatgpt-Account-Id': a.id_token.chatgpt_account_id,
        'Content-Type': 'application/json',
        Accept: payload ? 'text/event-stream' : 'application/json',
        Originator: 'codex-tui',
        'User-Agent': 'codex-tui/0.154.0'
      },
      ...(payload ? { data: JSON.stringify(payload) } : {})
    });
    if (result.status_code !== 200) throw new Error('Upstream HTTP ' + result.status_code);
    return result.body;
  }

  return {
    accounts,
    async quota(a) {
      const body = await upstream(a, 'GET', 'https://chatgpt.com/backend-api/wham/usage');
      const q = (typeof body === 'string' ? JSON.parse(body) : body).rate_limit;
      const primary = windowData(q?.primary_window);
      const weekly = windowData(q?.secondary_window);
      if (primary.seconds !== 18000 || weekly.seconds !== 604800 || typeof q.allowed !== 'boolean') {
        throw new Error('Unexpected quota contract');
      }
      return { allowed: q.allowed && !q.limit_reached, primary, weekly };
    },
    async activate(a) {
      const body = await upstream(a, 'POST', 'https://chatgpt.com/backend-api/codex/responses', {
        model: 'gpt-6.1-sol',
        instructions: 'Reply with OK only.',
        input: [{ role: 'user', content: [{ type: 'input_text', text: 'Reply OK.' }] }],
        stream: true,
        store: false,
        tools: [],
        reasoning: { effort: 'low' }
      });
      const events = body.split('\n')
        .filter(l => l.startsWith('data: '))
        .flatMap(l => {
          try { return [JSON.parse(l.slice(6))]; } catch { return []; }
        });
      const done = events.find(e => e.type === 'response.completed' && e.response?.status === 'completed');
      const text = (done?.response.output || [])
        .flatMap(i => i.content || [])
        .filter(c => c.type === 'output_text')
        .map(c => c.text)
        .join('') || events.filter(e => e.type === 'response.output_text.delta').map(e => e.delta || '').join('');
      if (!done || !text.trim()) throw new Error('No completed model output');
    },
    async plan(input) {
      const config = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));
      const result = await request(base + '/v1/chat/completions', config.apiKey, {
        model: config.model,
        reasoning_effort: 'low',
        messages: [
          {
            role: 'system',
            content: 'You schedule minimal wake-up requests for two Codex Plus accounts. Requests NEVER reset quotas; they MAY start an idle five-hour window. Optimize readiness for observed user demand, minimize idle windows and unnecessary requests, consider weekly budget and stagger accounts only when supported by data. Timezone Asia/Shanghai. Return JSON ONLY: {"date":"YYYY-MM-DD","accounts":[{"account":"auth_index","times":["07:00","12:00","17:00"],"reason":"中文理由"}]}. Exactly one entry per supplied account. Zero to three times per account, sorted, >=4 hours apart, only :00 or :30. If historyHours<24, retain the baseline 07:00,12:00,17:00 and explain insufficient data. Empty times is allowed when no wake-up is useful. Missing samples are unknown, not zero usage. Cross-reset intervals are lower bounds. Do not propose shell commands. Only plan the supplied date; past times will be ignored. Current active windows are skipped by executor.'
          },
          { role: 'user', content: JSON.stringify(input) }
        ],
        stream: false,
        max_tokens: 2200
      });
      const text = result.choices?.[0]?.message?.content;
      if (typeof text !== 'string') throw new Error('Missing planner output');
      return JSON.parse(text.trim().replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, ''));
    }
  };
}

async function sampleAll(api, state) {
  const latest = new Map();
  for (const a of api.accounts) {
    const sample = { time: Date.now(), account: a.auth_index, quota: null };
    try {
      sample.quota = await api.quota(a);
    } catch (e) {
      sample.error = e.message;
    }
    state.samples.push(sample);
    latest.set(a.auth_index, sample);
    log('sample', sample);
  }

  const cutoff = Date.now() - 30 * DAY;
  for (const key of ['samples', 'attempts', 'planning']) {
    state[key] = state[key].filter(x => x.time >= cutoff);
  }

  for (const attempt of state.attempts.filter(a => a.status === 'completed' && !a.observation)) {
    const s = latest.get(attempt.account);
    if (s?.quota && s.time > attempt.time) {
      attempt.observation = {
        time: s.time,
        resetBefore: attempt.resetBefore,
        resetAfter: s.quota.primary.reset,
        resetChanged: attempt.resetBefore !== s.quota.primary.reset,
        note: 'Observation only; concurrent user requests may also start a window.'
      };
    }
  }

  save(state);
  return latest;
}

async function makePlan(api, state, now) {
  const date = localDate(now);
  if (state.planning.some(p => p.date === date)) return;

  const attempt = { time: now, date, status: 'started' };
  state.planning.push(attempt);
  save(state);

  try {
    const rawPlan = await api.plan({
      date,
      now: new Date(now).toISOString(),
      accounts: api.accounts.map(a => a.auth_index),
      usage: summarize(state.samples, now),
      latest: api.accounts.map(a => state.samples.filter(s => s.account === a.auth_index).slice(-1)[0]),
      previousAttempts: state.attempts.slice(-20)
    });
    const plan = validatePlan(rawPlan, date, api.accounts.map(a => a.auth_index));
    state.plan = { ...plan, createdAt: Date.now() };
    attempt.status = 'completed';
    log('plan', state.plan);
  } catch (e) {
    attempt.status = 'failed';
    attempt.error = e.message;
    log('plan-failed', { error: e.message });
  }
  save(state);
}

async function execute(api, state, latest, now) {
  const date = localDate(now);
  const plan = state.plan?.date === date ? state.plan : {
    date,
    accounts: api.accounts.map(a => ({
      account: a.auth_index,
      times: state.plan?.accounts.find(p => p.account === a.auth_index)?.times || ['07:00', '12:00', '17:00']
    }))
  };

  for (const a of api.accounts) {
    const entry = plan.accounts.find(p => p.account === a.auth_index);
    for (const time of entry?.times || []) {
      const due = at(date, time);
      const key = date + '/' + a.auth_index + '/' + time;
      if (now < due || now - due >= HALF_HOUR || state.attempts.some(x => x.key === key)) {
        continue;
      }

      const sample = latest.get(a.auth_index);
      const reason = activationDecision(state, a.auth_index, sample, now);
      const attempt = {
        time: Date.now(),
        account: a.auth_index,
        key,
        status: reason ? 'skipped' : 'started',
        reason,
        resetBefore: sample?.quota?.primary.reset
      };

      state.attempts.push(attempt);
      save(state);

      if (reason) {
        log('activation-skipped', { account: a.auth_index, reason });
        continue;
      }

      try {
        await api.activate(a);
        attempt.status = 'completed';
        try {
          const q = await api.quota(a);
          attempt.immediateObservation = {
            time: Date.now(),
            resetBefore: attempt.resetBefore,
            resetAfter: q.primary.reset,
            resetChanged: attempt.resetBefore !== q.primary.reset,
            note: 'Immediate observation; next half-hour sample will confirm.'
          };
        } catch (e) {
          attempt.observationError = e.message;
        }
      } catch (e) {
        attempt.status = 'failed';
        attempt.error = e.message;
      }

      save(state);
      log('activation', attempt);
    }
  }
}

function getStatusObject(state) {
  const now = Date.now();
  const summary = summarize(state.samples, now);
  const accounts = [...new Set([
    ...(state.plan?.accounts || []).map(a => a.account),
    ...state.samples.map(s => s.account)
  ])];
  const latestSamples = accounts.map(id => state.samples.filter(s => s.account === id).slice(-1)[0]).filter(Boolean);

  return {
    time: new Date(now).toISOString(),
    event: 'status',
    managedBy: 'AccessDeck',
    samplesCount: state.samples.length,
    latestSamples,
    plan: state.plan,
    planning: state.planning.slice(-5),
    attempts: state.attempts.slice(-20),
    summary: {
      timezone: summary.timezone,
      validSamples: summary.validSamples,
      historyHours: summary.historyHours
    }
  };
}

function startServer(port = 8318) {
  const server = http.createServer((req, res) => {
    // 跨域支持与只读状态响应
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    const url = new URL(req.url, 'http://localhost');
    if (url.pathname === '/status' || url.pathname === '/v0/scheduler/status') {
      try {
        const state = load();
        const obj = getStatusObject(state);
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify(obj, null, 2));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
      return;
    }

    if (url.pathname === '/health') {
      try {
        const state = load();
        const latest = state.samples.slice(-1)[0];
        const ageMs = latest ? Date.now() - latest.time : Infinity;
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          status: 'ok',
          latestSampleAgeSeconds: Math.round(ageMs / 1000),
          isStale: ageMs > 45 * 60000
        }));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'error', error: e.message }));
      }
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not Found' }));
  });

  server.listen(port, '0.0.0.0', () => {
    log('server-started', { port, host: '0.0.0.0' });
  });

  return server;
}

async function main() {
  const mode = process.argv[2] || '--tick';
  if (!['--tick', '--sample', '--plan', '--execute', '--status', '--serve'].includes(mode)) {
    throw new Error('Use --tick, --sample, --plan, --execute, --status or --serve');
  }

  fs.mkdirSync(DIR, { recursive: true, mode: 0o700 });
  const state = load();

  if (mode === '--serve') {
    startServer(8318);
    return;
  }

  if (mode === '--status') {
    const obj = getStatusObject(state);
    console.log(JSON.stringify(obj));
    return;
  }

  const api = await connect();
  const latest = await sampleAll(api, state);
  const now = Date.now();
  if (mode === '--plan' || (mode === '--tick' && minute(now) >= 240)) {
    await makePlan(api, state, now);
  }
  if (mode === '--tick' || mode === '--execute') {
    await execute(api, state, latest, Date.now());
  }
}

if (require.main === module) {
  main().catch(e => {
    log('fatal', { error: e.message });
    process.exitCode = 1;
  });
}

module.exports = {
  localDate,
  minute,
  at,
  windowData,
  summarize,
  validatePlan,
  activationDecision,
  execute,
  makePlan,
  getStatusObject,
  startServer
};
