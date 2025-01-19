import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub fn decode(msg) -> List(String) {
  case msg {
    "+" <> rest -> [rest |> string.trim]
    "*" <> rest -> decode_array(rest)
    "$" <> rest -> decode_bulk_string(rest)
    _ -> [msg]
  }
}

fn decode_array(msg: String) -> List(String) {
  let assert Ok(splitonrn) = string.split_once(msg, "\r\n")
  let #(size, rest) = case splitonrn {
    #(num, rest) -> #(num |> int.parse |> result.unwrap(0), rest)
  }
  rest |> build_array(size)
}

fn build_array(msg: String, size) -> List(String) {
  let splitonrn = string.split(msg, "\r\n")
  let assert [first, second, ..rest] = splitonrn
  let rest = rest |> string.join("\r\n")
  case first |> string.first() {
    Ok("*") -> decode_array(rest)
    Ok(_) ->
      [{ first <> "\r\n" <> second } |> decode, determine_rest(rest, size - 1)]
      |> list.flatten

    _ -> panic
  }
}

fn determine_rest(msg: String, size) -> List(String) {
  case size {
    0 -> []
    _ -> build_array(msg, size)
  }
}

fn decode_bulk_string(msg) {
  let assert Ok(splitonrn) = string.split_once(msg, "\r\n")
  let #(_size, rest) = case splitonrn {
    #(num, rest) -> #(num |> int.parse |> result.unwrap(0), rest)
  }
  [rest |> string.trim]
}
