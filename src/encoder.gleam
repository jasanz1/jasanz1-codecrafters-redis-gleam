import gleam/int
import gleam/option
import gleam/string

pub fn encode_simple_string(msg) -> String {
  "+" <> msg <> "\r\n"
}

pub fn encode_bulk_string(msg) -> String {
  case msg {
    None -> "$-1\r\n"
    Some(msg) ->
      "$" <> msg |> string.length |> int.to_string <> "\r\n" <> msg <> "\r\n"
  }
}
