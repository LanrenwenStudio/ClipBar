'use strict';
// AccessDeck - Codex Plus 调度器独立断言与回归测试套件

const assert = require('node:assert');
const {
  localDate,
  minute,
  at,
  windowData,
  summarize,
  validatePlan,
  activationDecision
} = require('./scheduler.cjs');

console.log('Running Codex Scheduler Test Suite...');

// 1. localDate & minute 测试
{
  const tsUtcNoon = Date.parse('2026-10-20T12:00:00Z'); // 北京时间 20:00
  assert.strictEqual(localDate(tsUtcNoon), '2026-10-20');
  assert.strictEqual(minute(tsUtcNoon), 20 * 60);

  const tsUtcMidnight = Date.parse('2026-10-20T16:30:00Z'); // 北京时间 2026-10-21 00:30
  assert.strictEqual(localDate(tsUtcMidnight), '2026-10-21');
  assert.strictEqual(minute(tsUtcMidnight), 30);
  console.log('✓ localDate & minute: passed');
}

// 2. windowData 校验与边界拦截
{
  const valid = windowData({ used_percent: 45.5, reset_at: 1792487918, limit_window_seconds: 18000 });
  assert.strictEqual(valid.used, 45.5);
  assert.strictEqual(valid.reset, 1792487918000);
  assert.strictEqual(valid.seconds, 18000);

  assert.throws(() => windowData(null), /Invalid quota window/);
  assert.throws(() => windowData({ used_percent: -1, reset_at: 100 }), /Invalid quota window/);
  assert.throws(() => windowData({ used_percent: 101, reset_at: 100 }), /Invalid quota window/);
  assert.throws(() => windowData({ used_percent: 50, reset_at: NaN }), /Invalid quota window/);
  console.log('✓ windowData validation: passed');
}

// 3. validatePlan 契约校验
{
  const date = '2026-10-20';
  const ids = ['acc-1', 'acc-2'];

  // 合法计划
  const validPlan = {
    date: '2026-10-20',
    accounts: [
      { account: 'acc-1', times: ['07:00', '12:00', '17:00'], reason: '正常调度' },
      { account: 'acc-2', times: ['08:00', '13:30'], reason: '错峰' }
    ]
  };
  assert.deepStrictEqual(validatePlan(validPlan, date, ids), validPlan);

  // 空 times 允许（不安排唤醒）
  const emptyTimesPlan = {
    date: '2026-10-20',
    accounts: [
      { account: 'acc-1', times: [], reason: '今日已耗尽无需唤醒' },
      { account: 'acc-2', times: ['12:00'], reason: '单次唤醒' }
    ]
  };
  assert.deepStrictEqual(validatePlan(emptyTimesPlan, date, ids), emptyTimesPlan);

  // 日期不符
  assert.throws(() => validatePlan({ date: '2026-10-21', accounts: validPlan.accounts }, date, ids), /Invalid plan date/);
  // 缺少账号
  assert.throws(() => validatePlan({ date, accounts: [validPlan.accounts[0]] }, date, ids), /Invalid plan date/);
  // 包含未知账号
  assert.throws(() => validatePlan({
    date,
    accounts: [
      { account: 'acc-1', times: ['07:00'], reason: 'ok' },
      { account: 'acc-unknown', times: ['07:00'], reason: 'ok' }
    ]
  }, date, ids), /Invalid account plan/);
  // 非法时间格式
  assert.throws(() => validatePlan({
    date,
    accounts: [
      { account: 'acc-1', times: ['07:15'], reason: 'ok' },
      { account: 'acc-2', times: [], reason: 'ok' }
    ]
  }, date, ids), /Invalid plan time/);
  // 间隔不足四小时
  assert.throws(() => validatePlan({
    date,
    accounts: [
      { account: 'acc-1', times: ['07:00', '10:30'], reason: 'ok' },
      { account: 'acc-2', times: [], reason: 'ok' }
    ]
  }, date, ids), /Plan times must be sorted and four hours apart/);
  console.log('✓ validatePlan rules: passed');
}

// 4. activationDecision 决策判定
{
  const now = at('2026-10-20', '12:00');
  const account = 'acc-1';

  // 4.1 样本过期或不存在
  assert.strictEqual(activationDecision({ attempts: [] }, account, null, now), 'quota-unavailable');
  assert.strictEqual(activationDecision({ attempts: [] }, account, { time: now - 11 * 60000, quota: { allowed: true } }, now), 'quota-unavailable');

  // 4.2 额度耗尽
  const exhaustedSample1 = {
    time: now - 1000,
    quota: { allowed: false, primary: { used: 50, reset: now + 3600000 }, weekly: { used: 50, reset: now + 3600000 } }
  };
  assert.strictEqual(activationDecision({ attempts: [] }, account, exhaustedSample1, now), 'quota-exhausted');

  const exhaustedSample2 = {
    time: now - 1000,
    quota: { allowed: true, primary: { used: 100, reset: now + 3600000 }, weekly: { used: 50, reset: now + 3600000 } }
  };
  assert.strictEqual(activationDecision({ attempts: [] }, account, exhaustedSample2, now), 'quota-exhausted');

  // 4.3 窗口已处于活跃状态
  const activeSample = {
    time: now - 1000,
    quota: { allowed: true, primary: { used: 15, reset: now + 3600000 }, weekly: { used: 20, reset: now + 86400000 } }
  };
  assert.strictEqual(activationDecision({ attempts: [] }, account, activeSample, now), 'window-already-active');

  // 4.4 每日上限 3 次
  const idleSample = {
    time: now - 1000,
    quota: { allowed: true, primary: { used: 0, reset: now - 1000 }, weekly: { used: 20, reset: now + 86400000 } }
  };
  const stateCapped = {
    attempts: [
      { account, time: at('2026-10-20', '07:00'), status: 'completed' },
      { account, time: at('2026-10-20', '08:00'), status: 'failed' },
      { account, time: at('2026-10-20', '09:00'), status: 'started' }
    ]
  };
  assert.strictEqual(activationDecision(stateCapped, account, idleSample, now), 'daily-cap');

  // 4.5 最小间隔不足四小时
  const stateRecent = {
    attempts: [
      { account, time: now - 3 * 3600000, status: 'completed' }
    ]
  };
  assert.strictEqual(activationDecision(stateRecent, account, idleSample, now), 'minimum-interval');

  // 4.6 允许执行
  const stateOk = {
    attempts: [
      { account, time: now - 5 * 3600000, status: 'completed' }
    ]
  };
  assert.strictEqual(activationDecision(stateOk, account, idleSample, now), null);

  // 4.7 之前的 skipped 记录不计入每日上限和四小时间隔
  const stateSkipped = {
    attempts: [
      { account, time: now - 10 * 60000, status: 'skipped', reason: 'window-already-active' },
      { account, time: now - 30 * 60000, status: 'skipped', reason: 'window-already-active' },
      { account, time: now - 60 * 60000, status: 'skipped', reason: 'window-already-active' }
    ]
  };
  assert.strictEqual(activationDecision(stateSkipped, account, idleSample, now), null);
  console.log('✓ activationDecision rules: passed');
}

// 5. summarize 消耗统计与跨 reset 测试
{
  const now = at('2026-10-20', '12:00');
  const t0 = now - 60 * 60000;
  const t1 = now - 30 * 60000;
  const t2 = now;

  // 连续采样同 reset
  const samplesSame = [
    { time: t0, account: 'a1', quota: { primary: { used: 10, reset: now + 3600000 } } },
    { time: t1, account: 'a1', quota: { primary: { used: 25, reset: now + 3600000 } } }
  ];
  const sum1 = summarize(samplesSame, now);
  assert.strictEqual(sum1.last24Hours.length, 1);
  assert.strictEqual(sum1.last24Hours[0].consumedPercent, 15);
  assert.strictEqual(sum1.last24Hours[0].crossedReset, false);

  // 跨 reset：新窗口 used 从 0 增长到 12，只记新窗口的 12
  const samplesCross = [
    { time: t0, account: 'a1', quota: { primary: { used: 40, reset: t1 - 1000 } } },
    { time: t1, account: 'a1', quota: { primary: { used: 12, reset: now + 18000000 } } }
  ];
  const sum2 = summarize(samplesCross, now);
  assert.strictEqual(sum2.last24Hours.length, 1);
  assert.strictEqual(sum2.last24Hours[0].consumedPercent, 12);
  assert.strictEqual(sum2.last24Hours[0].crossedReset, true);

  // 间隔超过 45 分钟断片：不统计消耗
  const samplesGapped = [
    { time: now - 90 * 60000, account: 'a1', quota: { primary: { used: 10, reset: now + 3600000 } } },
    { time: now, account: 'a1', quota: { primary: { used: 30, reset: now + 3600000 } } }
  ];
  const sum3 = summarize(samplesGapped, now);
  assert.strictEqual(sum3.last24Hours.length, 0);
  console.log('✓ summarize consumption & cross-reset: passed');
}

console.log('\nAll Codex Scheduler unit tests passed successfully!');
