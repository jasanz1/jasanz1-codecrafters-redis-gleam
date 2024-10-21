import gleam/io
pub fn encode(msg) -> String {
  simple_string(msg)
}

fn simple_string(msg) -> String {
  "+" <> msg <> "\r\n"
}
