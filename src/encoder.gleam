import gleam/int
import gleam/string

pub fn encode_simple_string(msg) -> String {
  "+" <> msg <> "\r\n"
}

pub fn encode_bulk_string(msg) -> String {
  "$" <> msg |> string.length |> int.to_string <> "\r\n" <> msg <> "\r\n"
}
