use cpal::traits::{DeviceTrait, HostTrait};
use serde::Serialize;

#[derive(Serialize)]
struct ProbeBuffer {
    kind: String,
    min_frames: u32,
    max_frames: u32,
}

#[derive(Serialize)]
struct ProbeConfig {
    channels: u32,
    sample_rate: u32,
    sample_format: String,
    buffer: ProbeBuffer,
}

#[derive(Serialize)]
struct ProbeConfigRange {
    channels: u32,
    min_sample_rate: u32,
    max_sample_rate: u32,
    sample_format: String,
    buffer: ProbeBuffer,
}

#[derive(Serialize)]
struct ProbeDevice {
    id_ok: bool,
    id: String,
    name_ok: bool,
    name: String,
    supports_input: bool,
    supports_output: bool,
    has_default_input_config: bool,
    default_input_config: ProbeConfig,
    has_default_output_config: bool,
    default_output_config: ProbeConfig,
    supported_input_configs_ok: bool,
    supported_input_configs: Vec<ProbeConfigRange>,
    supported_output_configs_ok: bool,
    supported_output_configs: Vec<ProbeConfigRange>,
}

#[derive(Serialize)]
struct ProbeHost {
    id: String,
    devices_ok: bool,
    devices: Vec<ProbeDevice>,
    has_default_input_device: bool,
    default_input_device_id_ok: bool,
    default_input_device_id: String,
    has_default_output_device: bool,
    default_output_device_id_ok: bool,
    default_output_device_id: String,
}

#[derive(Serialize)]
struct ProbeSnapshot {
    all_hosts: Vec<String>,
    available_hosts: Vec<String>,
    default_host: String,
    hosts: Vec<ProbeHost>,
}

fn empty_buffer() -> ProbeBuffer {
    ProbeBuffer {
        kind: "unknown".to_string(),
        min_frames: 0,
        max_frames: 0,
    }
}

fn empty_config() -> ProbeConfig {
    ProbeConfig {
        channels: 0,
        sample_rate: 0,
        sample_format: String::new(),
        buffer: empty_buffer(),
    }
}

fn probe_buffer(buffer: cpal::SupportedBufferSize) -> ProbeBuffer {
    match buffer {
        cpal::SupportedBufferSize::Unknown => empty_buffer(),
        cpal::SupportedBufferSize::Range { min, max } => ProbeBuffer {
            kind: "range".to_string(),
            min_frames: min,
            max_frames: max,
        },
    }
}

fn probe_config(config: cpal::SupportedStreamConfig) -> ProbeConfig {
    ProbeConfig {
        channels: config.channels() as u32,
        sample_rate: config.sample_rate(),
        sample_format: config.sample_format().to_string(),
        buffer: probe_buffer(config.buffer_size().clone()),
    }
}

fn probe_config_range(config: cpal::SupportedStreamConfigRange) -> ProbeConfigRange {
    ProbeConfigRange {
        channels: config.channels() as u32,
        min_sample_rate: config.min_sample_rate(),
        max_sample_rate: config.max_sample_rate(),
        sample_format: config.sample_format().to_string(),
        buffer: probe_buffer(config.buffer_size().clone()),
    }
}

fn probe_device_id(device: &cpal::Device) -> (bool, String) {
    match device.id() {
        Ok(id) => (true, id.to_string()),
        Err(_) => (false, String::new()),
    }
}

fn probe_device(device: cpal::Device) -> ProbeDevice {
    let (id_ok, id) = probe_device_id(&device);
    let (name_ok, name) = match device.description() {
        Ok(description) => (true, description.name().to_string()),
        Err(_) => (false, String::new()),
    };
    let supports_input = device.supports_input();
    let supports_output = device.supports_output();

    let (has_default_input_config, default_input_config) = match device.default_input_config() {
        Ok(config) => (true, probe_config(config)),
        Err(_) => (false, empty_config()),
    };
    let (has_default_output_config, default_output_config) = match device.default_output_config() {
        Ok(config) => (true, probe_config(config)),
        Err(_) => (false, empty_config()),
    };
    let (supported_input_configs_ok, supported_input_configs) =
        match device.supported_input_configs() {
            Ok(configs) => (true, configs.map(probe_config_range).collect()),
            Err(_) => (false, Vec::new()),
        };
    let (supported_output_configs_ok, supported_output_configs) =
        match device.supported_output_configs() {
            Ok(configs) => (true, configs.map(probe_config_range).collect()),
            Err(_) => (false, Vec::new()),
        };

    ProbeDevice {
        id_ok,
        id,
        name_ok,
        name,
        supports_input,
        supports_output,
        has_default_input_config,
        default_input_config,
        has_default_output_config,
        default_output_config,
        supported_input_configs_ok,
        supported_input_configs,
        supported_output_configs_ok,
        supported_output_configs,
    }
}

fn probe_default_device_id(device: Option<cpal::Device>) -> (bool, bool, String) {
    match device {
        None => (false, false, String::new()),
        Some(device) => {
            let (id_ok, id) = probe_device_id(&device);
            (true, id_ok, id)
        }
    }
}

fn probe_host(host_id: cpal::HostId) -> ProbeHost {
    let host = cpal::host_from_id(host_id).expect("available host_from_id failed");
    let (devices_ok, devices) = match host.devices() {
        Ok(devices) => (true, devices.map(probe_device).collect()),
        Err(_) => (false, Vec::new()),
    };
    let (has_default_input_device, default_input_device_id_ok, default_input_device_id) =
        probe_default_device_id(host.default_input_device());
    let (has_default_output_device, default_output_device_id_ok, default_output_device_id) =
        probe_default_device_id(host.default_output_device());

    ProbeHost {
        id: host_id.to_string(),
        devices_ok,
        devices,
        has_default_input_device,
        default_input_device_id_ok,
        default_input_device_id,
        has_default_output_device,
        default_output_device_id_ok,
        default_output_device_id,
    }
}

fn snapshot() -> ProbeSnapshot {
    let available_hosts = cpal::available_hosts();

    ProbeSnapshot {
        all_hosts: cpal::ALL_HOSTS
            .iter()
            .map(|host_id| host_id.to_string())
            .collect(),
        available_hosts: available_hosts
            .iter()
            .map(|host_id| host_id.to_string())
            .collect(),
        default_host: cpal::default_host().id().to_string(),
        hosts: available_hosts.into_iter().map(probe_host).collect(),
    }
}

fn main() {
    let snapshot = snapshot();
    println!(
        "{}",
        serde_json::to_string(&snapshot).expect("serialize parity snapshot")
    );
}
