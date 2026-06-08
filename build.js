const os = require('os');

const platform = os.platform();
const moduleName = 'moonbit-community/moon_cpal';

const linkConfigs = [];

function pkg(path) {
  return path.length === 0 ? moduleName : `${moduleName}/${path}`;
}

function addLinkConfig(path, config) {
  linkConfigs.push({
    package: pkg(path),
    ...config,
  });
}

if (platform === 'darwin') {
  const frameworkFlags =
    '-framework CoreAudio -framework CoreFoundation -framework AudioToolbox';
  [
    'macos',
    'platform',
    'spec',
    'traits',
    'cmd/enumerate',
    'cmd/parity_probe',
    'cmd/macos_smoke',
    'cmd/macos_stream_smoke',
  ].forEach((path) => {
    addLinkConfig(path, { link_flags: frameworkFlags });
  });
} else if (platform === 'linux') {
  addLinkConfig('alsa', { link_flags: '-pthread', link_libs: ['asound'] });
  addLinkConfig('jack', { link_flags: '-pthread', link_libs: ['jack'] });
  addLinkConfig('internal/test_host', { link_flags: '-pthread' });
  addLinkConfig('platform', {
    link_flags: '-pthread',
    link_libs: ['asound', 'jack'],
  });
  addLinkConfig('spec', {
    link_flags: '-pthread',
    link_libs: ['asound', 'jack'],
  });
  addLinkConfig('traits', {
    link_flags: '-pthread',
    link_libs: ['asound', 'jack'],
  });
  addLinkConfig('cmd/enumerate', {
    link_flags: '-pthread',
    link_libs: ['asound', 'jack'],
  });
  addLinkConfig('cmd/parity_probe', {
    link_flags: '-pthread',
    link_libs: ['asound', 'jack'],
  });
  addLinkConfig('cmd/alsa_stream_smoke', {
    link_flags: '-pthread',
    link_libs: ['asound'],
  });
  addLinkConfig('cmd/jack_stream_smoke', {
    link_flags: '-pthread',
    link_libs: ['jack'],
  });
} else if (platform === 'win32') {
  const winLibs = ['ole32', 'uuid', 'mmdevapi', 'avrt'];
  ['wasapi', 'platform', 'spec', 'traits', 'cmd/enumerate', 'cmd/parity_probe', 'cmd/wasapi_stream_smoke'].forEach(
    (path) => {
      addLinkConfig(path, { link_libs: winLibs });
    },
  );
} else {
  throw new Error(`Unsupported platform for moon_cpal prebuild: ${platform}`);
}

console.log(
  JSON.stringify({
    link_configs: linkConfigs,
  }),
);
