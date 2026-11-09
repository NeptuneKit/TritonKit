// CLI argv contract: no shell, generic flags, executable override, or output paths.
export function fail(code, message) { return Object.assign(new Error(message), { code }); }

function object(value, keys) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw fail('invalid_arguments', 'Expected an object');
  for (const key of Object.keys(value)) if (!keys.includes(key)) throw fail('invalid_arguments', `Unknown field: ${key}`);
}
function text(value, name, { max = 4096, optionSafe = true } = {}) {
  if (typeof value !== 'string' || !value.length || value.length > max || /[\x00\r\n]/u.test(value) || (optionSafe && value.startsWith('-'))) {
    throw fail('invalid_arguments', `Invalid ${name}`);
  }
  return value;
}
function choice(value, values, name) {
  if (!values.includes(value)) throw fail('invalid_arguments', `Invalid ${name}; expected ${values.join(', ')}`);
  return value;
}
function number(value, name, min = 0, max = 100000, integer = false) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max || (integer && !Number.isInteger(value))) throw fail('invalid_arguments', `Invalid ${name}`);
  return String(value);
}
const platforms = ['ios', 'android', 'harmony'];
function platform(args, argv) {
  if (args.platform !== undefined) argv.push('--platform', choice(args.platform, platforms, 'platform'));
}
function target(args, argv, flag = '--target') {
  const value = text(args.target, 'target', { max: 512 });
  // CLI aliases are bare names and are resolved before raw IDs. Requiring the
  // discovery namespace also rejects aliases shaped like raw serials or UUIDs.
  if (!/^(?:sim|ios-real|android|harmony|triton):[^\s]+$/u.test(value) || /(?:^|[:/])(local|current|booted|default|alias)(?:$|[:/])/iu.test(value)) {
    throw fail('invalid_arguments', 'Use a namespaced discovery ID (sim:, ios-real:, android:, harmony: or triton:), not a bare alias, raw ID or default selector');
  }
  argv.push(flag, value);
}

export function resolveConfig(raw = {}, env = process.env) {
  object(raw, ['executable', 'timeoutMs', 'maxOutputBytes']);
  const executable = raw.executable ?? env.TRITONKIT_TRITON_BIN ?? 'triton';
  text(executable, 'executable', { max: 4096 });
  if (!executable.startsWith('/') && !/^[a-zA-Z0-9_-]+$/u.test(executable)) throw fail('invalid_config', 'executable must be an absolute path or bare command');
  const timeoutMs = raw.timeoutMs ?? 30000;
  const maxOutputBytes = raw.maxOutputBytes ?? 262144;
  number(timeoutMs, 'timeoutMs', 10, 120000, true);
  number(maxOutputBytes, 'maxOutputBytes', 1024, 1048576, true);
  return { executable, timeoutMs, maxOutputBytes };
}

export function buildCommand(kind, args) {
  // Strict tool backends may require every declared field. Null is an explicit
  // omission for known optional fields only; unknown fields still fail validation.
  const nullable = {
    schema: ['command'], query: ['platform', 'target', 'maxNodes'],
    action: ['platform', 'query', 'x', 'y', 'text', 'oid', 'button', 'startX', 'startY', 'endX', 'endY', 'duration'],
    verify: ['role', 'count'],
  };
  if (args && typeof args === 'object' && !Array.isArray(args)) {
    args = Object.fromEntries(Object.entries(args).filter(([key, value]) => !(value === null && nullable[kind]?.includes(key))));
  }
  if (kind === 'schema') {
    object(args, ['command']);
    const argv = ['schema'];
    if (args.command !== undefined) {
      const command = text(args.command, 'command', { max: 128 });
      if (!/^[a-z][a-z0-9.-]*(?: [a-z][a-z0-9.-]*)*$/u.test(command)) throw fail('invalid_arguments', 'command must be a CLI command path');
      argv.push('--command', command);
    }
    return [...argv, '--json'];
  }
  if (kind === 'query') {
    const operations = ['version', 'status', 'doctor', 'capabilities', 'plan', 'targets', 'observe-current', 'observe-tree'];
    choice(args?.operation, operations, 'operation');
    if (operations.slice(0, 5).includes(args.operation)) {
      object(args, ['operation']);
      return [args.operation, '--json'];
    }
    if (args.operation === 'targets') {
      object(args, ['operation', 'platform']);
      return ['target', 'list', '--platform', choice(args.platform, platforms, 'platform'), '--json'];
    }
    object(args, ['operation', 'platform', 'target', 'maxNodes']);
    const argv = ['observe', args.operation === 'observe-tree' ? 'tree' : 'current'];
    choice(args.platform, platforms, 'platform');
    platform(args, argv);
    // observe uses --device for iOS host selection; Android/Harmony use raw --target.
    target(args, argv, args.platform === 'ios' ? '--device' : '--target');
    argv.push('--max-nodes', number(args.maxNodes ?? 100, 'maxNodes', 1, 1000, true));
    return [...argv, '--json'];
  }
  if (kind === 'action') {
    choice(args?.action, ['tap', 'type', 'press', 'swipe'], 'action');
    const shared = ['action', 'target', 'platform'];
    const allowed = {
      tap: ['query', 'x', 'y'], type: ['text', 'oid'], press: ['button'],
      swipe: ['startX', 'startY', 'endX', 'endY', 'duration'],
    };
    object(args, [...shared, ...allowed[args.action]]);
    const argv = ['act', args.action];
    target(args, argv);
    // CLI type/press only expose Android/Harmony host adapters; no invented iOS flag.
    if (args.platform === 'ios' && ['type', 'press'].includes(args.action)) throw fail('invalid_arguments', 'For iOS type/press use an embedded runtime target and omit platform');
    platform(args, argv);
    if (args.action === 'tap') {
      if (args.query !== undefined) {
        if (args.x !== undefined || args.y !== undefined) throw fail('invalid_arguments', 'Choose query OR x/y');
        argv.push('--text', text(args.query, 'query'));
      } else {
        argv.push('--x', number(args.x, 'x'), '--y', number(args.y, 'y'));
      }
    } else if (args.action === 'type') {
      argv.push('--text', text(args.text, 'text'), '--secure');
      if (args.oid !== undefined) {
        if (args.platform !== undefined || typeof args.oid !== 'string' || !/^[0-9]{1,20}$/u.test(args.oid) || BigInt(args.oid) > 18446744073709551615n) {
          throw fail('invalid_arguments', 'oid must be a decimal UInt64 string for embedded runtime input, without a host platform');
        }
        argv.push('--oid', args.oid);
      }
    } else if (args.action === 'press') {
      argv.push('--button', choice(args.button, ['home', 'back', 'lock', 'power', 'volume-up', 'volume-down'], 'button'));
    } else {
      for (const [field, flag] of [['startX', '--start-x'], ['startY', '--start-y'], ['endX', '--end-x'], ['endY', '--end-y']]) argv.push(flag, number(args[field], field));
      if (args.duration !== undefined) argv.push('--duration', number(args.duration, 'duration', 0.05, 5));
    }
    return [...argv, '--json'];
  }
  if (kind === 'verify') {
    object(args, ['condition', 'target', 'text', 'role', 'count']);
    const argv = ['verify', choice(args.condition, ['text-exists', 'text-not-exists'], 'condition')];
    target(args, argv);
    if (args.role !== undefined) argv.push('--role', text(args.role, 'role', { max: 128 }));
    if (args.count !== undefined) argv.push('--count', number(args.count, 'count', 0, 10000, true));
    return [...argv, '--json', '--', text(args.text, 'text', { optionSafe: false })];
  }
  throw fail('invalid_arguments', 'Unknown tool kind');
}
