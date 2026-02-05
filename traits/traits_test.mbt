///|
test "traits: HostTrait/DeviceTrait/StreamTrait roundtrip (best-effort)" {
  let host = @spec.default_host()
  let _id = host.id()

  // Exercise trait dispatch.
  let _ = HostTrait::default_output_device(host)
  match HostTrait::default_output_device(host) {
    None => inspect(true, content="true")
    Some(dev) => {
      let _ = DeviceTrait::supports_output(dev)
      let _ = try DeviceTrait::id(dev) catch {
        _ => @core.DeviceId::new(_id, "")
      } noraise {
        x => x
      }
      let cfg = try DeviceTrait::default_output_config(dev) catch {
        _ => None
      } noraise {
        x => Some(x)
      }
      match cfg {
        None => inspect(true, content="true")
        Some(cfg) => {
          let sc = cfg.config()
          let stream = try
            DeviceTrait::build_output_stream_raw(
              dev,
              sc,
              cfg.sample_format(),
              fn(data, _info) { data.clear() },
              fn(_e) { () },
              None,
            )
          catch {
            _ => None
          } noraise {
            s => Some(s)
          }
          match stream {
            None => inspect(true, content="true")
            Some(s) => {
              // Stream lifecycle calls should not crash.
              try StreamTrait::play(s) catch {
                _ => ()
              } noraise {
                _ => ()
              }
              try StreamTrait::pause(s) catch {
                _ => ()
              } noraise {
                _ => ()
              }
              StreamTrait::close(s)
              inspect(true, content="true")
            }
          }
        }
      }
    }
  }
}
