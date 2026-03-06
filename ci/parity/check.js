const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..');
const outDir = path.join(root, '_build', 'parity');

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

function sortStrings(xs) {
  return [...xs].sort();
}

function projectConfig(config) {
  return {
    channels: config.channels,
    sample_rate: config.sample_rate,
    sample_format: config.sample_format,
    buffer: {
      kind: config.buffer.kind,
      min_frames: config.buffer.min_frames,
      max_frames: config.buffer.max_frames,
    },
  };
}

function projectRange(range) {
  return {
    channels: range.channels,
    min_sample_rate: range.min_sample_rate,
    max_sample_rate: range.max_sample_rate,
    sample_format: range.sample_format,
    buffer: {
      kind: range.buffer.kind,
      min_frames: range.buffer.min_frames,
      max_frames: range.buffer.max_frames,
    },
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
    .map((device) => ({
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
    }))
    .sort((a, b) =>
      `${a.id_ok ? '1' : '0'}:${a.id}`.localeCompare(
        `${b.id_ok ? '1' : '0'}:${b.id}`,
        'en',
      ),
    );
}

function sortHosts(hosts) {
  return [...hosts]
    .map((host) => ({
      id: host.id,
      devices_ok: host.devices_ok,
      has_default_input_device: host.has_default_input_device,
      default_input_device_id_ok: host.default_input_device_id_ok,
      default_input_device_id: host.default_input_device_id,
      has_default_output_device: host.has_default_output_device,
      default_output_device_id_ok: host.default_output_device_id_ok,
      default_output_device_id: host.default_output_device_id,
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
