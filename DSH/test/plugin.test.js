import test from 'node:test';
import assert from 'node:assert/strict';
import { buildCommand, resolveConfig } from '../commands.js';
import { apply } from '../host.js';

const config = () => resolveConfig({}, {});
function fixture({ mode = 'danger-full-access', payload = { ok: true }, exitCode = 0, stderr = '', lossy = false, hang = false } = {}) {
  const tools = new Map();
  const disposers = [];
  const calls = [];
  const active = new Set();
  const ctx = {
    effect(fn) { const dispose = fn(); disposers.push(dispose); return dispose; },
    tools: { register(tool) { tools.set(tool.name, tool); return () => tools.delete(tool.name); } },
    sandboxPolicy: { resolve: () => ({ mode }) },
    workingDirectory: { ensure: async () => '/fixture' },
    subprocess: {
      resolveExecutable: async name => { calls.push(['resolve', name]); return '/bin/triton'; },
      spawn(spec) {
        calls.push(spec);
        let settle;
        const done = new Promise(resolve => { settle = resolve; });
        active.add(spec);
        const finish = () => { active.delete(spec); settle({ exitCode, signal: null }); };
        spec.signal.addEventListener('abort', finish, { once: true });
        if (!hang) queueMicrotask(finish);
        return { done, terminate: finish, waitForExit: async () => !active.has(spec), collected: {
          stdout: { readFrom: () => ({ text: typeof payload === 'string' ? payload : JSON.stringify(payload), lossy }) },
          stderr: { readFrom: () => ({ text: stderr, lossy: false }) },
        } };
      },
    },
  };
  const exec = signal => ({ agent: { session: {} }, signal: signal ?? new AbortController().signal });
  return { ctx, tools, calls, active, exec, dispose: async () => { for (const fn of disposers.reverse()) await fn?.(); } };
}

test('configuration defaults, environment, explicit precedence and invalid values', () => {
  assert.equal(config().executable, 'triton');
  assert.equal(config().timeoutMs, 30000);
  assert.equal(resolveConfig({}, { TRITONKIT_TRITON_BIN: '/opt/triton' }).executable, '/opt/triton');
  assert.equal(resolveConfig({ executable: '/custom/triton' }, { TRITONKIT_TRITON_BIN: '/opt/triton' }).executable, '/custom/triton');
  for (const item of [{ timeoutMs: 0 }, { timeoutMs: '10' }, { maxOutputBytes: 0 }, { executable: './triton' }, { executable: '' }, { surprise: true }]) {
    assert.throws(() => resolveConfig(item, {}));
  }
});

test('strict tool backends can use null for known optional fields only', () => {
  assert.deepEqual(buildCommand('query', { operation: 'version', platform: null, target: null, maxNodes: null }), ['version', '--json']);
  assert.deepEqual(buildCommand('schema', { command: null }), ['schema', '--json']);
  assert.throws(() => buildCommand('query', { operation: 'version', unknown: null }));
  assert.throws(() => buildCommand('action', { action: 'type', target: null, text: 'x' }));
});

test('schema selector is one literal argument; unknown keys fail', () => {
  assert.deepEqual(buildCommand('schema', { command: 'act.tap' }), ['schema', '--command', 'act.tap', '--json']);
  assert.throws(() => buildCommand('schema', { command: '--output=/tmp/pwn' }));
  assert.throws(() => buildCommand('query', { operation: 'version', args: ['serve'] }));
  assert.throws(() => buildCommand('query', { operation: 'serve' }));
});

test('observation is bounded, target-explicit and never outline or output', () => {
  assert.deepEqual(buildCommand('query', { operation: 'observe-current', platform: 'ios', target: 'sim:fixture', maxNodes: 50 }),
    ['observe', 'current', '--platform', 'ios', '--device', 'sim:fixture', '--max-nodes', '50', '--json']);
  assert.throws(() => buildCommand('query', { operation: 'observe-tree' }));
  assert.throws(() => buildCommand('query', { operation: 'observe-tree', platform: 'ios', target: '--help' }));
  assert.throws(() => buildCommand('query', { operation: 'targets' }));
});

test('actions bind exact target and flags; text stays literal', () => {
  assert.deepEqual(buildCommand('action', { action: 'type', target: 'triton:fixture', text: 'hi; $(touch /tmp/no)' }),
    ['act', 'type', '--target', 'triton:fixture', '--text', 'hi; $(touch /tmp/no)', '--secure', '--json']);
  assert.deepEqual(buildCommand('action', { action: 'tap', target: 'sim:fixture', x: 10, y: 20 }),
    ['act', 'tap', '--target', 'sim:fixture', '--x', '10', '--y', '20', '--json']);
  for (const args of [
    { action: 'tap' }, { action: 'tap', target: 'x', x: 1 },
    { action: 'tap', target: 'x', query: 'x', x: 1, y: 2 },
    { action: 'type', target: 'x', text: '--help' },
    { action: 'type', target: 'x', text: 'ok', executable: '/bin/sh' },
    { action: 'press', target: 'x', button: '--help' },
    { action: 'swipe', target: 'x', startX: NaN, startY: 0, endX: 1, endY: 1 },
  ]) assert.throws(() => buildCommand('action', args));
});

test('verification uses end-of-options to preserve text beginning with dash', () => {
  assert.deepEqual(buildCommand('verify', { condition: 'text-exists', target: 'triton:fixture', text: '--version', count: 1 }),
    ['verify', 'text-exists', '--target', 'triton:fixture', '--count', '1', '--json', '--', '--version']);
});

test('four tools register, preserve raw payload and dispose', async () => {
  const f = fixture();
  apply(f.ctx, {});
  assert.deepEqual([...f.tools.keys()], ['triton_schema', 'triton_query', 'triton_action', 'triton_verify']);
  const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
  assert.equal(result.success, true);
  assert.deepEqual(result.payload, { ok: true });
  assert.equal(f.calls[1].cwd, '/fixture');
  assert.deepEqual(f.calls[1].argv, ['/bin/triton', 'version', '--json']);
  assert.equal(f.calls[1].stdio.stdin, 'ignore');
  await f.dispose();
  assert.equal(f.tools.size, 0);
});

test('all tools fail closed outside Full access without spawning', async () => {
  for (const mode of ['read-only', 'workspace-write']) {
    const f = fixture({ mode }); apply(f.ctx, {});
    const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
    assert.equal(result.error.code, 'permission_denied');
    assert.equal(f.calls.length, 0);
    await f.dispose();
  }
});

test('nonzero exit, ok:false and partial payloads are not successful', async () => {
  for (const facts of [
    { exitCode: 2, payload: { ok: false, error: { code: 'target_not_found' } } },
    { payload: { ok: false } }, { payload: { ok: true, partial: true } },
  ]) {
    const f = fixture(facts); apply(f.ctx, {});
    const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
    assert.equal(result.success, false);
    assert.deepEqual(result.payload, facts.payload);
    await f.dispose();
  }
});

test('stderr error envelope is retained without double wrapping', async () => {
  const raw = { ok: false, error: { code: 'connection_refused' } };
  const f = fixture({ exitCode: 1, payload: '', stderr: JSON.stringify(raw) }); apply(f.ctx, {});
  const result = await f.tools.get('triton_query').execute({ operation: 'status' }, f.exec());
  assert.deepEqual(result.payload, raw);
  assert.equal(result.payloadStream, 'stderr');
  await f.dispose();
});

test('invalid JSON and truncated output stay explicit failures', async () => {
  for (const facts of [{ payload: 'not-json' }, { lossy: true }]) {
    const f = fixture(facts); apply(f.ctx, {});
    const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
    assert.equal(result.success, false);
    assert.equal(result.error.code, facts.lossy ? 'output_truncated' : 'invalid_json');
    await f.dispose();
  }
});

test('cancellation and unload terminate owned calls', async () => {
  const f = fixture({ hang: true }); apply(f.ctx, {});
  const abort = new AbortController();
  const task = f.tools.get('triton_query').execute({ operation: 'version' }, f.exec(abort.signal));
  await new Promise(resolve => setImmediate(resolve));
  abort.abort();
  assert.equal((await task).error.code, 'cancelled');
  assert.equal(f.active.size, 0);
  await f.dispose();
});

test('unload cancels running and queued calls, without starting queued commands', async () => {
  const f = fixture({ hang: true }); apply(f.ctx, {});
  const tool = f.tools.get('triton_query');
  const first = tool.execute({ operation: 'version' }, f.exec());
  const second = tool.execute({ operation: 'version' }, f.exec());
  await new Promise(resolve => setImmediate(resolve));
  await f.dispose();
  assert.equal((await first).error.code, 'cancelled');
  assert.equal((await second).error.code, 'cancelled');
  assert.equal(f.calls.filter(call => call.argv).length, 1);
});

test('schema without ok is successful and suggested commands are only returned', async () => {
  const payload = { schemaVersion: 1, commands: [{ name: 'serve', nextAction: 'do not execute' }] };
  const f = fixture({ payload }); apply(f.ctx, {});
  const result = await f.tools.get('triton_schema').execute({ command: 'status' }, f.exec());
  assert.equal(result.success, true);
  assert.deepEqual(result.payload, payload);
  assert.equal(f.calls.filter(call => call.argv).length, 1);
  await f.dispose();
});

test('timeout cancels the owned command and never retries', async () => {
  const f = fixture({ hang: true }); apply(f.ctx, { timeoutMs: 10 });
  const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
  assert.equal(result.error.code, 'timeout');
  assert.equal(f.active.size, 0);
  assert.equal(f.calls.filter(call => call.argv).length, 1);
  await f.dispose();
});

test('missing executable and spawn failures are reported without retries', async () => {
  for (const field of ['resolveExecutable', 'spawn']) {
    const f = fixture();
    let attempts = 0;
    f.ctx.subprocess[field] = () => { attempts++; throw new Error('fixture failure'); };
    apply(f.ctx, {});
    const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
    assert.equal(result.error.code, 'execution_failed');
    assert.equal(attempts, 1);
    await f.dispose();
  }
});

test('permission downgrade during async executable resolution prevents spawn', async () => {
  const f = fixture();
  let mode = 'danger-full-access';
  f.ctx.sandboxPolicy.resolve = () => ({ mode });
  f.ctx.subprocess.resolveExecutable = async () => { mode = 'read-only'; return '/bin/triton'; };
  apply(f.ctx, {});
  const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
  assert.equal(result.error?.code, 'permission_denied');
  assert.equal(f.calls.filter(call => call.argv).length, 0);
  await f.dispose();
});

test('pre-cancelled calls and calls without an agent never spawn', async () => {
  const f = fixture(); apply(f.ctx, {});
  const abort = new AbortController(); abort.abort();
  const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec(abort.signal));
  assert.equal(result.error.code, 'cancelled');
  const noAgent = await f.tools.get('triton_query').execute({ operation: 'version' }, { signal: new AbortController().signal });
  assert.equal(noAgent.error.code, 'agent_required');
  assert.equal(f.calls.length, 0);
  await f.dispose();
});

test('dynamic target defaults cannot be used for actions or assertions', () => {
  for (const target of ['local', 'triton:local', 'current', 'booted', 'ios:current', 'sim:booted', 'alias:phone', '  current  ']) {
    assert.throws(() => buildCommand('action', { action: 'tap', target, x: 1, y: 2 }));
    assert.throws(() => buildCommand('verify', { condition: 'text-exists', target, text: 'Done' }));
  }
});

test('oid is a bounded UInt string and not accepted with a host adapter', () => {
  assert.ok(buildCommand('action', { action: 'type', target: 'triton:fixture', text: 'x', oid: '18446744073709551615' }).includes('18446744073709551615'));
  for (const oid of ['node-12', '-1', '18446744073709551616', '1.2', 12]) assert.throws(() => buildCommand('action', { action: 'type', target: 'triton:fixture', text: 'x', oid }));
  assert.throws(() => buildCommand('action', { action: 'type', target: 'android:fixture', platform: 'android', text: 'x', oid: '12' }));
});

test('range quiescence, not direct outcome, owns the shared queue', async () => {
  const f = fixture();
  let rangeLive = true;
  let release;
  const quiescence = new Promise(resolve => { release = () => { rangeLive = false; resolve(true); }; });
  const spawn = f.ctx.subprocess.spawn;
  let starts = 0;
  f.ctx.subprocess.spawn = spec => {
    starts++;
    if (starts > 1) assert.equal(rangeLive, false);
    return { ...spawn(spec), waitForExit: () => quiescence };
  };
  apply(f.ctx, {});
  const tool = f.tools.get('triton_query');
  const first = tool.execute({ operation: 'version' }, f.exec());
  const second = tool.execute({ operation: 'version' }, f.exec());
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(starts, 1);
  release();
  await Promise.all([first, second]);
  assert.equal(starts, 2);
  await f.dispose();
});

test('unconfirmed cleanup blocks subsequent dispatch and is retried during unload', async () => {
  const f = fixture();
  let confirmed = false;
  const spawn = f.ctx.subprocess.spawn;
  f.ctx.subprocess.spawn = spec => ({ ...spawn(spec), waitForExit: async () => confirmed });
  apply(f.ctx, {});
  const tool = f.tools.get('triton_query');
  assert.equal((await tool.execute({ operation: 'version' }, f.exec())).error.code, 'cleanup_uncertain');
  assert.equal((await tool.execute({ operation: 'version' }, f.exec())).error.code, 'cleanup_uncertain');
  assert.equal(f.calls.filter(call => call.argv).length, 1);
  confirmed = true;
  await f.dispose();
});

test('queued cancellation returns before the running command exits and never spawns', async () => {
  const f = fixture({ hang: true }); apply(f.ctx, {});
  const firstAbort = new AbortController();
  const queuedAbort = new AbortController();
  const tool = f.tools.get('triton_query');
  const first = tool.execute({ operation: 'version' }, f.exec(firstAbort.signal));
  const queued = tool.execute({ operation: 'version' }, f.exec(queuedAbort.signal));
  await new Promise(resolve => setImmediate(resolve));
  queuedAbort.abort();
  assert.equal((await queued).error.code, 'cancelled');
  assert.equal(f.active.size, 1);
  firstAbort.abort();
  await first;
  await f.dispose();
  assert.equal(f.calls.filter(call => call.argv).length, 1);
});

test('timeout and provider rejection preserve already collected CLI error payload', async () => {
  const raw = { ok: false, error: { code: 'original_error' } };
  const f = fixture({ hang: true, payload: raw }); apply(f.ctx, { timeoutMs: 10 });
  const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
  assert.equal(result.error.code, 'timeout');
  assert.deepEqual(result.payload, raw);
  await f.dispose();
});

test('provider rejection retains the CLI payload and confirms process cleanup', async () => {
  const payload = { ok: false, error: { code: 'original_error' } };
  const f = fixture({ payload });
  const spawn = f.ctx.subprocess.spawn;
  f.ctx.subprocess.spawn = spec => ({ ...spawn(spec), done: Promise.reject(new Error('provider failure')) });
  apply(f.ctx, {});
  const result = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
  assert.equal(result.error.code, 'execution_failed');
  assert.deepEqual(result.payload, payload);
  assert.equal(result.cleanup, 'confirmed');
  await f.dispose();
});

test('missing session and permission changes during directory preparation fail closed', async () => {
  const f = fixture();
  let mode = 'danger-full-access';
  f.ctx.sandboxPolicy.resolve = () => ({ mode });
  f.ctx.workingDirectory.ensure = async () => { mode = 'workspace-write'; return '/fixture'; };
  apply(f.ctx, {});
  const missing = await f.tools.get('triton_query').execute({ operation: 'version' }, { ...f.exec(), agent: {} });
  assert.equal(missing.error.code, 'agent_required');
  const downgrade = await f.tools.get('triton_query').execute({ operation: 'version' }, f.exec());
  assert.equal(downgrade.error.code, 'permission_denied');
  assert.equal(f.calls.filter(call => call.argv).length, 0);
  await f.dispose();
});

test('tool schemas have bounded output and no arbitrary argv surface', () => {
  const f = fixture(); apply(f.ctx, {});
  for (const tool of f.tools.values()) {
    assert.equal(tool.parameters.additionalProperties, false);
    assert.ok(tool.output.schema);
    assert.equal(tool.isConcurrencySafe({}), false);
    assert.equal(tool.output.render({}, { success: false })[0].type, 'text');
  }
});
