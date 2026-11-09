import { buildCommand, resolveConfig } from './commands.js';

export const inject = ['tools', 'subprocess', 'workingDirectory', 'sandboxPolicy'];

const string = description => ({ type: 'string', description });
const numeric = description => ({ type: 'number', description });
const enumeration = (values, description) => ({ type: 'string', enum: values, description });
const target = string('Concrete discovery target ID, not local/current/booted/default or aliases. iOS observation uses a host device selector; actions/verification use the selector required by that CLI command.');
const platform = enumeration(['ios', 'android', 'harmony'], 'Host adapter; omit for embedded runtime actions. iOS type/press require an embedded target without this field.');
const definitions = [
  {
    kind: 'schema', name: 'triton_schema',
    description: 'Read TritonKit CLI command contracts, including parameters and recovery guidance. Requires DSH Full access. Returned commands are suggestions, not permission to execute them.',
    properties: { command: string('Optional command path, e.g. act.tap or observe current. Omit for the full directory; prefer a specific command to bound output.') }, required: [],
  },
  {
    kind: 'query', name: 'triton_query',
    description: 'Query TritonKit version, service status, diagnostics, capabilities, bootstrap plan, targets or visible UI. Requires DSH Full access; probes may contact local services, collect device data or create provider artifacts. Never starts a server or executes a returned plan.',
    properties: {
      operation: enumeration(['version', 'status', 'doctor', 'capabilities', 'plan', 'targets', 'observe-current', 'observe-tree'], 'Query to run. version/status/doctor/capabilities/plan accept no other fields.'),
      platform: { ...platform, description: 'Required for targets and observe-* only: ios, android or harmony.' },
      target: { ...target, description: 'Required for observe-* only. iOS: host device selector (sim:<UDID>); Android/Harmony: raw target id.' },
      maxNodes: { type: 'integer', minimum: 1, maximum: 1000, description: 'observe-* only; default 100, maximum 1000.' },
    }, required: ['operation'],
  },
  {
    kind: 'action', name: 'triton_action',
    description: 'Perform one explicit TritonKit tap, text insertion, button press or swipe. Requires DSH Full access and user authorization for the target/effect; calls are serialized. Inspect first, verify business state afterwards. Timeout or cancellation may leave delivery unknown: never retry automatically. Input text is recorded in DSH tool history even though CLI output is redacted.',
    properties: {
      action: enumeration(['tap', 'type', 'press', 'swipe'], 'One action; only its relevant fields are accepted.'), target, platform,
      query: string('tap only: visible text/label/identifier; exclusive with x/y. Refresh observation before use.'),
      x: numeric('tap only: x in window points, paired with y, range 0...100000.'),
      y: numeric('tap only: y in window points, paired with x, range 0...100000.'),
      text: string('type only: nonempty single-line text up to 4096 characters, not starting with a dash. Do not pass credentials; DSH records arguments.'),
      oid: string('type only: optional responder oid as a decimal UInt64 string (0...18446744073709551615) from a fresh observation; incompatible with a host platform.'),
      button: enumeration(['home', 'back', 'lock', 'power', 'volume-up', 'volume-down'], 'press only: device button; backend support varies.'),
      startX: numeric('swipe only: start x in window points, range 0...100000.'),
      startY: numeric('swipe only: start y in window points, range 0...100000.'),
      endX: numeric('swipe only: end x in window points, range 0...100000.'),
      endY: numeric('swipe only: end y in window points, range 0...100000.'),
      duration: { type: 'number', minimum: 0.05, maximum: 5, description: 'swipe only: optional duration in seconds; backend default if omitted.' },
    }, required: ['action', 'target'],
  },
  {
    kind: 'verify', name: 'triton_verify',
    description: 'Assert visible text exists or is absent through the TritonKit runtime. Requires DSH Full access, an explicit runtime target and a reachable existing server. Returns the original assertion payload; an action acknowledgement alone is not verification.',
    properties: {
      condition: enumeration(['text-exists', 'text-not-exists'], 'Expected text condition.'), target,
      text: string('Visible text, AX label or identifier; nonempty single-line, up to 4096 characters.'),
      role: string('Optional AX role filter, up to 128 characters.'),
      count: { type: 'integer', minimum: 0, maximum: 10000, description: 'Optional exact match count.' },
    }, required: ['condition', 'target', 'text'],
  },
];

function failure(code, message, extra = {}) {
  return { ...extra, success: false, error: { code, message } };
}
function readOutput(handle) {
  const stdout = handle.collected.stdout?.readFrom(0) ?? { text: '', lossy: false };
  const stderr = handle.collected.stderr?.readFrom(0) ?? { text: '', lossy: false };
  return { stdout: stdout.text, stderr: stderr.text, truncated: Boolean(stdout.lossy || stderr.lossy) };
}
function parseResult(output, outcome) {
  const result = { ...output, exitCode: outcome.exitCode, signal: outcome.signal };
  if (output.truncated) return failure('output_truncated', 'Output exceeded the configured limit; do not infer success from the retained tail', result);
  let payload, payloadStream;
  for (const stream of ['stdout', 'stderr']) {
    if (!output[stream].trim()) continue;
    try {
      const value = JSON.parse(output[stream]);
      if (value && typeof value === 'object' && !Array.isArray(value)) {
        payload = value; payloadStream = stream; break;
      }
    } catch { /* CLI parser errors may be plain text on stderr. */ }
  }
  if (payload === undefined) return failure('invalid_json', 'CLI did not return one complete JSON object', result);
  // schema has no ok field. Preserve the CLI document, not a second {ok:false} envelope.
  const success = outcome.exitCode === 0 && outcome.signal === null && payload.ok !== false && payload.partial !== true && !payload.error && !(payload.skipped ?? []).some?.(item => item?.error);
  return { success, ...result, payload, payloadStream };
}

export function apply(ctx, rawConfig = {}) {
  const config = resolveConfig(rawConfig);
  const lifetime = new AbortController();
  const active = new Set();
  let cleanupBlocked = false;
  let tail = Promise.resolve();

  // A direct outcome does not prove the provider-owned process range is empty.
  async function waitForRange(handle) {
    const abort = new AbortController();
    let timer;
    try {
      return await Promise.race([
        Promise.resolve().then(() => handle.waitForExit(abort.signal)).catch(() => false),
        new Promise(resolve => { timer = setTimeout(() => { abort.abort(); resolve(false); }, 1500); }),
      ]) === true;
    } finally { clearTimeout(timer); }
  }
  async function cleanup(handle, terminateFirst = false) {
    if (terminateFirst) { try { handle.terminate(); } catch { /* range proof still required */ } }
    let confirmed = await waitForRange(handle);
    if (!confirmed) {
      try { handle.terminate(); } catch { /* never assume termination succeeded */ }
      confirmed = await waitForRange(handle);
    }
    if (confirmed) active.delete(handle);
    return confirmed;
  }
  ctx.effect(() => async () => {
    lifetime.abort();
    await tail;
    for (const handle of active) await cleanup(handle, true);
    if (active.size) throw new Error('TritonKit cleanup remains unconfirmed; the subprocess provider retains ownership');
  });

  function permitted(exec) {
    return ctx.sandboxPolicy.resolve({ session: exec.agent.session }).mode === 'danger-full-access';
  }
  function stopped(deadline, extra = {}) {
    return failure(deadline.aborted ? 'timeout' : 'cancelled', 'Execution stopped; action delivery may be unknown. Inspect state before any further action.', extra);
  }
  function captured(handle, outcome = { exitCode: null, signal: null }) {
    try { return parseResult(readOutput(handle), outcome); }
    catch { return failure('output_unavailable', 'Provider output could not be read'); }
  }
  async function run(kind, args, exec, deadline) {
    const signal = exec.signal;
    if (signal.aborted) return stopped(deadline);
    if (cleanupBlocked) return failure('cleanup_uncertain', 'A previous process range is not confirmed empty; unload/reload only after investigating the owned process');
    let handle, result;
    try {
      const argv = buildCommand(kind, args);
      if (!exec.agent?.session) return failure('agent_required', 'A session-owned call is required');
      // The subprocess seam is not a sandbox. Never bypass session policy.
      if (!permitted(exec)) return failure('permission_denied', 'TritonKit tools require DSH Full access; no automatic escalation is performed');
      const cwd = await ctx.workingDirectory.ensure(exec.agent, signal);
      const executable = await ctx.subprocess.resolveExecutable(config.executable, undefined, signal);
      signal.throwIfAborted();
      // Recheck after async preparation, at the synchronous spawn boundary.
      if (!permitted(exec)) return failure('permission_denied', 'DSH permission changed before dispatch; command was not started');
      handle = ctx.subprocess.spawn({
        argv: [executable, ...argv], cwd, signal, graceMs: 1000,
        stdio: { stdin: 'ignore', stdout: { maxBytes: config.maxOutputBytes }, stderr: { maxBytes: config.maxOutputBytes } },
      });
      active.add(handle);
      const outcome = await handle.done;
      result = captured(handle, outcome);
    } catch (error) {
      // Preserve any complete CLI error document already emitted before provider failure.
      result = failure(error.code ?? 'execution_failed', String(error.message ?? error), handle ? captured(handle) : {});
    }
    if (handle) {
      const confirmed = await cleanup(handle, signal.aborted || result.error?.code === 'execution_failed');
      result = { ...result, cleanup: confirmed ? 'confirmed' : 'unknown' };
      if (!confirmed) {
        cleanupBlocked = true;
        return failure('cleanup_uncertain', 'Managed process range could not be confirmed empty; subsequent dispatch is blocked', result);
      }
    }
    return signal.aborted ? stopped(deadline, result) : result;
  }

  for (const definition of definitions) {
    const { kind, properties, required, ...schema } = definition;
    ctx.effect(() => ctx.tools.register({
      ...schema,
      parameters: {
        type: 'object',
        properties: Object.fromEntries(Object.entries(properties).map(([key, property]) => {
          if (required.includes(key)) return [key, property];
          const { description, ...shape } = property;
          return [key, { oneOf: [shape, { type: 'null' }], description: `${description} Use null when not applicable.` }];
        })),
        required, additionalProperties: false,
      },
      output: {
        schema: { type: 'object', properties: { success: { type: 'boolean' } }, required: ['success'], additionalProperties: true },
        render: (_args, value) => [{ type: 'text', text: JSON.stringify(value, null, 2) }],
      },
      timeoutMs: config.timeoutMs + 5000,
      isConcurrencySafe: () => false,
      execute(args, exec) {
        // Deadline includes queue time. Cancellation of a queued call returns immediately,
        // while its skipped placeholder preserves the queue's process-ownership order.
        const deadline = new AbortController();
        const timer = setTimeout(() => deadline.abort(), config.timeoutMs);
        const signal = AbortSignal.any([exec.signal, lifetime.signal, deadline.signal]);
        let started = false;
        let onAbort;
        const queuedAbort = new Promise(resolve => {
          onAbort = () => { if (!started) resolve(stopped(deadline.signal)); };
          signal.addEventListener('abort', onAbort, { once: true });
          if (signal.aborted) onAbort();
        });
        const task = tail.then(() => {
          started = true;
          return run(kind, args, { ...exec, signal }, deadline.signal);
        });
        tail = task.catch(() => {});
        return Promise.race([task, queuedAbort]).finally(() => {
          clearTimeout(timer);
          signal.removeEventListener('abort', onAbort);
        });
      },
    }));
  }
}
