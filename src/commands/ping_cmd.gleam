import encoder
import gleam/option.{Some}

pub fn ping_cmd() {
  encoder.encode_simple_string(Some("PONG"))
}
