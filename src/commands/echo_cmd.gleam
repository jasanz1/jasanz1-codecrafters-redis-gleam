import encoder
import gleam/option

pub fn echo_cmd(msg) -> String {
  encoder.encode_simple_string(option.Some(msg))
}
