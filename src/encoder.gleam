import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn encode_simple_string(msg) -> String {
  "+" <> msg |> option.unwrap("") <> "\r\n"
}

pub fn encode_bulk_string(msg) -> String {
  case msg {
    None -> "$-1\r\n"
    Some(msg) ->
      "$" <> msg |> string.length |> int.to_string <> "\r\n" <> msg <> "\r\n"
  }
}

pub fn encode_array(msg, element_encoder) -> String {
  io.debug(msg)
  case msg {
    [] -> "*0\r\n"
    rest -> {
      let rest = rest |> list.map(fn(x) { element_encoder(Some(x)) })
      "*" <> int.to_string(list.length(rest)) <> "\r\n" <> rest |> string.concat
    }
  }
}
