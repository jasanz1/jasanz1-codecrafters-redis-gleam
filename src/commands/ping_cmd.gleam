import encoder
pub fn ping_cmd() {
  encoder.encode_simple_string("PONG")
}
