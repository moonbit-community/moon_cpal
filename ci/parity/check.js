const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const outDir = path.join(root, '_build', 'parity');
const upstreamDoc = path.join(root, 'UPSTREAM.md');

function loadUpstreamReference() {
  const text = fs.readFileSync(upstreamDoc, 'utf8');
  const repoMatch = text.match(/Upstream repo:\s+([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)/);
  const commitMatch = text.match(/Pinned commit .*: `([0-9a-f]{40})`/);
  if (!repoMatch || !commitMatch) {
    throw new Error(`failed to parse upstream reference from ${upstreamDoc}`);
  }
  return {
    repo: repoMatch[1],
    commit: commitMatch[1],
  };
}

function runChecked(name, command, args) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: 'utf8',
    env: {
      ...process.env,
      CARGO_TARGET_DIR: path.join(root, '_build', 'cargo', 'cpal_reference_probe'),
    },
  });
  if (result.error) {
    throw new Error(`${name} failed to start: ${result.error.message}`);
  }
  if (result.status !== 0) {
    throw new Error(
      `${name} failed with exit code ${result.status}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
    );
  }
  return result.stdout.trim();
}

function ensureReferenceCheckout() {
  const { repo, commit } = loadUpstreamReference();
  const referenceDir = path.join(root, 'cpal-reference');
  const cargoManifest = path.join(referenceDir, 'Cargo.toml');
  if (fs.existsSync(cargoManifest)) {
    const head = runChecked('cpal-reference rev-parse', 'git', [
      '-C',
      referenceDir,
      'rev-parse',
      'HEAD',
    ]);
    if (head === commit) {
      return;
    }
  }

  if (!fs.existsSync(referenceDir)) {
    runChecked('clone cpal-reference', 'git', [
      'clone',
      '--filter=blob:none',
      '--no-checkout',
      `https://github.com/${repo}.git`,
      referenceDir,
    ]);
  } else if (!fs.existsSync(path.join(referenceDir, '.git'))) {
    throw new Error(`${referenceDir} exists but is not a git checkout`);
  }

  runChecked('fetch cpal-reference commit', 'git', [
    '-C',
    referenceDir,
    'fetch',
    '--depth',
    '1',
    'origin',
    commit,
  ]);
  runChecked('checkout cpal-reference commit', 'git', [
    '-C',
    referenceDir,
    'checkout',
    '--detach',
    commit,
  ]);
}

function sortStrings(xs) {
  return [...xs].sort();
}

function clampMoonInt(value) {
  return Math.min(value, 0x7fffffff);
}

function projectConfig(config) {
  return {
    channels: config.channels,
    sample_rate: clampMoonInt(config.sample_rate),
    sample_format: config.sample_format,
    buffer: {
      kind: config.buffer.kind,
      min_frames: clampMoonInt(config.buffer.min_frames),
      max_frames: clampMoonInt(config.buffer.max_frames),
    },
  };
}

function projectRange(range) {
  return {
    channels: range.channels,
    min_sample_rate: clampMoonInt(range.min_sample_rate),
    max_sample_rate: clampMoonInt(range.max_sample_rate),
    sample_format: range.sample_format,
    buffer: {
      kind: range.buffer.kind,
      min_frames: clampMoonInt(range.buffer.min_frames),
      max_frames: clampMoonInt(range.buffer.max_frames),
    },
  };
}

function projectBuild(build) {
  return {
    raw_ok: build.raw_ok,
    has_typed_probe: build.has_typed_probe,
    typed_kind: build.typed_kind,
    typed_ok: build.typed_ok,
  };
}

function sortRanges(ranges) {
  return [...ranges]
    .map(projectRange)
    .sort((a, b) =>
      JSON.stringify(a).localeCompare(JSON.stringify(b), 'en'),
    );
}

function sortDevices(devices) {
  return [...devices]
    .map(projectDevice)
    .sort((a, b) =>
      `${a.id_ok ? '1' : '0'}:${a.id}`.localeCompare(
        `${b.id_ok ? '1' : '0'}:${b.id}`,
        'en',
      ),
    );
}

function projectDevice(device) {
  return {
    id_ok: device.id_ok,
    id: device.id,
    name_ok: device.name_ok,
    name: device.name,
    supports_input: device.supports_input,
    supports_output: device.supports_output,
    has_default_input_config: device.has_default_input_config,
    default_input_config: projectConfig(device.default_input_config),
    has_default_output_config: device.has_default_output_config,
    default_output_config: projectConfig(device.default_output_config),
    supported_input_configs_ok: device.supported_input_configs_ok,
    supported_input_configs: sortRanges(device.supported_input_configs),
    supported_output_configs_ok: device.supported_output_configs_ok,
    supported_output_configs: sortRanges(device.supported_output_configs),
  };
}

function projectDefaultDevice(host, kind) {
  const hasKey = `has_default_${kind}_device`;
  const idOkKey = `default_${kind}_device_id_ok`;
  const idKey = `default_${kind}_device_id`;
  if (!host[hasKey]) {
    return {
      present: false,
    };
  }
  const match = host.devices.find(
    (device) => device.id_ok === host[idOkKey] && device.id === host[idKey],
  );
  return {
    present: true,
    id_ok: host[idOkKey],
    id: host[idKey],
    listed: match !== undefined,
  };
}

function sortHosts(hosts) {
  return [...hosts]
    .map((host) => ({
      id: host.id,
      devices_ok: host.devices_ok,
      default_input_device: projectDefaultDevice(host, 'input'),
      has_default_input_build_probe: host.has_default_input_build_probe,
      default_input_build: projectBuild(host.default_input_build),
      default_output_device: projectDefaultDevice(host, 'output'),
      has_default_output_build_probe: host.has_default_output_build_probe,
      default_output_build: projectBuild(host.default_output_build),
      devices: sortDevices(host.devices),
    }))
    .sort((a, b) => a.id.localeCompare(b.id, 'en'));
}

function projectSnapshot(snapshot) {
  return {
    all_hosts: sortStrings(snapshot.all_hosts),
    available_hosts: sortStrings(snapshot.available_hosts),
    default_host: snapshot.default_host,
    hosts: sortHosts(snapshot.hosts),
  };
}

function diff(a, b, currentPath, out) {
  if (typeof a !== typeof b) {
    out.push(`${currentPath}: type mismatch (${typeof a} vs ${typeof b})`);
    return;
  }

  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) {
      out.push(`${currentPath}: length mismatch (${a.length} vs ${b.length})`);
    }
    const n = Math.min(a.length, b.length);
    for (let i = 0; i < n; i += 1) {
      diff(a[i], b[i], `${currentPath}[${i}]`, out);
    }
    return;
  }

  if (a && b && typeof a === 'object') {
    const keys = [...new Set([...Object.keys(a), ...Object.keys(b)])].sort();
    for (const key of keys) {
      if (!(key in a)) {
        out.push(`${currentPath}.${key}: missing in rust snapshot`);
        continue;
      }
      if (!(key in b)) {
        out.push(`${currentPath}.${key}: missing in moon snapshot`);
        continue;
      }
      diff(a[key], b[key], `${currentPath}.${key}`, out);
    }
    return;
  }

  if (a !== b) {
    out.push(
      `${currentPath}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`,
    );
  }
}

function writeArtifacts(rustRaw, moonRaw, rustProjected, moonProjected) {
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(
    path.join(outDir, 'cpal_reference_probe.json'),
    JSON.stringify(rustRaw, null, 2),
  );
  fs.writeFileSync(
    path.join(outDir, 'moon_cpal_probe.json'),
    JSON.stringify(moonRaw, null, 2),
  );
  fs.writeFileSync(
    path.join(outDir, 'cpal_reference_projected.json'),
    JSON.stringify(rustProjected, null, 2),
  );
  fs.writeFileSync(
    path.join(outDir, 'moon_cpal_projected.json'),
    JSON.stringify(moonProjected, null, 2),
  );
}

function main() {
  ensureReferenceCheckout();

  const cargoArgs = [
    'run',
    '--quiet',
    '--locked',
    '--manifest-path',
    'ci/cpal_reference_probe/Cargo.toml',
  ];
  if (process.platform === 'linux') {
    cargoArgs.push('--features', 'cpal/jack');
  }

  const rustRaw = JSON.parse(runChecked('cpal-reference probe', 'cargo', cargoArgs));
  const moonRaw = JSON.parse(
    runChecked('moon_cpal probe', 'moon', ['run', '--target', 'native', 'cmd/parity_probe']),
  );

  const rustProjected = projectSnapshot(rustRaw);
  const moonProjected = projectSnapshot(moonRaw);
  writeArtifacts(rustRaw, moonRaw, rustProjected, moonProjected);

  const differences = [];
  diff(rustProjected, moonProjected, 'snapshot', differences);
  if (differences.length > 0) {
    const head = differences.slice(0, 40).join('\n');
    throw new Error(
      `cpal parity mismatch (${differences.length} differences)\n${head}\nArtifacts: ${outDir}`,
    );
  }

  console.log('cpal parity check passed');
}

main();
