use cpal::traits::{DeviceTrait, HostTrait};
use cpal::{I24, Sample, SampleFormat, StreamConfig, U24};
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
struct ProbeBuild {
    raw_ok: bool,
    has_typed_probe: bool,
    typed_kind: String,
    typed_ok: bool,
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
    has_default_input_build_probe: bool,
    default_input_build: ProbeBuild,
    has_default_output_device: bool,
    default_output_device_id_ok: bool,
    default_output_device_id: String,
    has_default_output_build_probe: bool,
    default_output_build: ProbeBuild,
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

fn empty_build() -> ProbeBuild {
    ProbeBuild {
        raw_ok: false,
        has_typed_probe: false,
        typed_kind: String::new(),
        typed_ok: false,
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

fn typed_probe_kind(sample_format: SampleFormat) -> Option<&'static str> {
    match sample_format {
        SampleFormat::F32 => Some("f32"),
        SampleFormat::I16 => Some("i16"),
        SampleFormat::U16 => Some("u16"),
        SampleFormat::U8 => Some("u8"),
        _ => None,
    }
}

fn clear_output_data(data: &mut cpal::Data) {
    match data.sample_format() {
        SampleFormat::I8 => data
            .as_slice_mut::<i8>()
            .expect("i8 output buffer")
            .fill(<i8 as Sample>::EQUILIBRIUM),
        SampleFormat::U8 => data
            .as_slice_mut::<u8>()
            .expect("u8 output buffer")
            .fill(<u8 as Sample>::EQUILIBRIUM),
        SampleFormat::I16 => data
            .as_slice_mut::<i16>()
            .expect("i16 output buffer")
            .fill(<i16 as Sample>::EQUILIBRIUM),
        SampleFormat::U16 => data
            .as_slice_mut::<u16>()
            .expect("u16 output buffer")
            .fill(<u16 as Sample>::EQUILIBRIUM),
        SampleFormat::I24 => data
            .as_slice_mut::<I24>()
            .expect("i24 output buffer")
            .fill(<I24 as Sample>::EQUILIBRIUM),
        SampleFormat::U24 => data
            .as_slice_mut::<U24>()
            .expect("u24 output buffer")
            .fill(<U24 as Sample>::EQUILIBRIUM),
        SampleFormat::I32 => data
            .as_slice_mut::<i32>()
            .expect("i32 output buffer")
            .fill(<i32 as Sample>::EQUILIBRIUM),
        SampleFormat::U32 => data
            .as_slice_mut::<u32>()
            .expect("u32 output buffer")
            .fill(<u32 as Sample>::EQUILIBRIUM),
        SampleFormat::I64 => data
            .as_slice_mut::<i64>()
            .expect("i64 output buffer")
            .fill(<i64 as Sample>::EQUILIBRIUM),
        SampleFormat::U64 => data
            .as_slice_mut::<u64>()
            .expect("u64 output buffer")
            .fill(<u64 as Sample>::EQUILIBRIUM),
        SampleFormat::F32 => data
            .as_slice_mut::<f32>()
            .expect("f32 output buffer")
            .fill(<f32 as Sample>::EQUILIBRIUM),
        SampleFormat::F64 => data
            .as_slice_mut::<f64>()
            .expect("f64 output buffer")
            .fill(<f64 as Sample>::EQUILIBRIUM),
        SampleFormat::DsdU8 | SampleFormat::DsdU16 | SampleFormat::DsdU32 => {
            data.bytes_mut().fill(0x69);
        }
        _ => {}
    }
}

fn probe_raw_output_build(
    device: &cpal::Device,
    config: &StreamConfig,
    sample_format: SampleFormat,
) -> bool {
    match device.build_output_stream_raw(
        config,
        sample_format,
        |data, _info| clear_output_data(data),
        |_err| {},
        None,
    ) {
        Ok(stream) => {
            drop(stream);
            true
        }
        Err(_) => false,
    }
}

fn probe_raw_input_build(
    device: &cpal::Device,
    config: &StreamConfig,
    sample_format: SampleFormat,
) -> bool {
    match device.build_input_stream_raw(config, sample_format, |_data, _info| {}, |_err| {}, None)
    {
        Ok(stream) => {
            drop(stream);
            true
        }
        Err(_) => false,
    }
}

fn probe_typed_output_build(device: &cpal::Device, config: &StreamConfig, sample_format: SampleFormat) -> (bool, String, bool) {
    let Some(kind) = typed_probe_kind(sample_format) else {
        return (false, String::new(), false);
    };
    let typed_ok = match sample_format {
        SampleFormat::F32 => match device.build_output_stream::<f32, _, _>(
            config,
            |data, _info| data.fill(<f32 as Sample>::EQUILIBRIUM),
            |_err| {},
            None,
        ) {
            Ok(stream) => {
                drop(stream);
                true
            }
            Err(_) => false,
        },
        SampleFormat::I16 => match device.build_output_stream::<i16, _, _>(
            config,
            |data, _info| data.fill(<i16 as Sample>::EQUILIBRIUM),
            |_err| {},
            None,
        ) {
            Ok(stream) => {
                drop(stream);
                true
            }
            Err(_) => false,
        },
        SampleFormat::U16 => match device.build_output_stream::<u16, _, _>(
            config,
            |data, _info| data.fill(<u16 as Sample>::EQUILIBRIUM),
            |_err| {},
            None,
        ) {
            Ok(stream) => {
                drop(stream);
                true
            }
            Err(_) => false,
        },
        SampleFormat::U8 => match device.build_output_stream::<u8, _, _>(
            config,
            |data, _info| data.fill(<u8 as Sample>::EQUILIBRIUM),
            |_err| {},
            None,
        ) {
            Ok(stream) => {
                drop(stream);
                true
            }
            Err(_) => false,
        },
        _ => false,
    };
    (true, kind.to_string(), typed_ok)
}

fn probe_typed_input_build(device: &cpal::Device, config: &StreamConfig, sample_format: SampleFormat) -> (bool, String, bool) {
    let Some(kind) = typed_probe_kind(sample_format) else {
        return (false, String::new(), false);
    };
    let typed_ok = match sample_format {
        SampleFormat::F32 => match device.build_input_stream::<f32, _, _>(
            config,
            |_data, _info| {},
            |_err| {},
            None,
        ) {
            Ok(stream) => {
                drop(stream);
                true
            }
            Err(_) => false,
        },
        SampleFormat::I16 => match device.build_input_stream::<i16, _, _>(
            config,
            |_data, _info| {},
            |_err| {},
            None,
        ) {
            Ok(stream) => {
                drop(stream);
                true
            }
            Err(_) => false,
        },
        SampleFormat::U16 => match device.build_input_stream::<u16, _, _>(
            config,
            |_data, _info| {},
            |_err| {},
            None,
        ) {
            Ok(stream) => {
                drop(stream);
                true
            }
            Err(_) => false,
        },
        SampleFormat::U8 => match device.build_input_stream::<u8, _, _>(
            config,
            |_data, _info| {},
            |_err| {},
            None,
        ) {
            Ok(stream) => {
                drop(stream);
                true
            }
            Err(_) => false,
        },
        _ => false,
    };
    (true, kind.to_string(), typed_ok)
}

fn probe_default_output_build(device: Option<cpal::Device>) -> (bool, ProbeBuild) {
    match device {
        None => (false, empty_build()),
        Some(device) => match device.default_output_config() {
            Ok(config) => {
                let stream_config = config.config();
                let sample_format = config.sample_format();
                let raw_ok = probe_raw_output_build(&device, &stream_config, sample_format);
                let (has_typed_probe, typed_kind, typed_ok) =
                    probe_typed_output_build(&device, &stream_config, sample_format);
                (
                    true,
                    ProbeBuild {
                        raw_ok,
                        has_typed_probe,
                        typed_kind,
                        typed_ok,
                    },
                )
            }
            Err(_) => (false, empty_build()),
        },
    }
}

fn probe_default_input_build(device: Option<cpal::Device>) -> (bool, ProbeBuild) {
    match device {
        None => (false, empty_build()),
        Some(device) => match device.default_input_config() {
            Ok(config) => {
                let stream_config = config.config();
                let sample_format = config.sample_format();
                let raw_ok = probe_raw_input_build(&device, &stream_config, sample_format);
                let (has_typed_probe, typed_kind, typed_ok) =
                    probe_typed_input_build(&device, &stream_config, sample_format);
                (
                    true,
                    ProbeBuild {
                        raw_ok,
                        has_typed_probe,
                        typed_kind,
                        typed_ok,
                    },
                )
            }
            Err(_) => (false, empty_build()),
        },
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
    let (has_default_input_build_probe, default_input_build) =
        probe_default_input_build(host.default_input_device());
    let (has_default_output_device, default_output_device_id_ok, default_output_device_id) =
        probe_default_device_id(host.default_output_device());
    let (has_default_output_build_probe, default_output_build) =
        probe_default_output_build(host.default_output_device());

    ProbeHost {
        id: host_id.to_string(),
        devices_ok,
        devices,
        has_default_input_device,
        default_input_device_id_ok,
        default_input_device_id,
        has_default_input_build_probe,
        default_input_build,
        has_default_output_device,
        default_output_device_id_ok,
        default_output_device_id,
        has_default_output_build_probe,
        default_output_build,
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
