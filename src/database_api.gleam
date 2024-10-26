import birl
import gleam/bit_array
import gleam/bytes_builder
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import state.{type State}

type Database {
  Database(
    magic: String,
    version: Int,
    meta: Dict(String, String),
    data: List(Data),
    checksum: Int,
  )
}

type EncodeType {
  String
  Int
}

type ExpiryType {
  Milliseconds(birl.Time)
  Seconds(birl.Time)
}

type Data {
  Data(
    index: Int,
    value_hash_size: Int,
    expiry_hash_size: Int,
    entries: List(Entry),
  )
}

type Entry {
  Entry(
    exipry: Option(ExpiryType),
    value_type: EncodeType,
    key: String,
    value: String,
  )
}

pub fn load_database(database_name, state: State) {
  let assert Ok(database) =
    database_name |> string.lowercase() |> simplifile.read_bits
  let database_base_16 = database |> bit_array.base16_encode
  let assert Ok(base_data) = database_base_16 |> get_header |> get_meta
}

fn get_header(data) {
  let #(magic, rest) = get_chars(data, 5)
  let #(version, rest) = get_chars(rest, 4)
  #(
    Database(magic, version |> int.parse |> result.unwrap(0), dict.new(), [], 0),
    rest,
  )
}

fn get_meta(input: #(Database, String)) {
  let #(database, rest) = input
  let assert Ok(#(_, rest)) = case rest |> get_word(1) {
    #(["F", "A"], rest) -> #(0, rest) |> Ok
    _ -> Error(Nil)
  }
  get_meta_subsections(rest) 
  Ok(rest)
}

fn get_meta_subsections(data) {
  let #(name, rest) = string_decode(data)
  io.debug(name)
  let #(value, rest) = string_decode(rest)
  io.debug(value)
  let #(peek, _) = rest |> get_word(2)
  let #(meta, rest) = case peek {
    ["F", "E"] -> #([], rest)
    _ -> get_meta_subsections(rest)
  }
  #([#(name, value), ..meta], rest)
}

fn string_decode(data) {
  let assert Ok(#(size, rest)) = parse_size(data)
  let assert Ok(size) = {size |> int.base_parse(16)} 
  get_chars(
    rest,
    size/8 
  )
}

fn parse_size(data) -> Result(#(String, String), String) {
  let #(size,rest_string) = get_bytes(data, 2) 
  let size = size |> string.join("")
  io.debug(size)
  io.debug(rest_string)
  case size |> bit_array.from_string{
    <<0b00:2, size:unsigned-6,rest:bits>> ->
      Ok(#(size|> int.to_string ,
        // rest|> bit_array.to_string |> result.unwrap("")<>
          rest_string))
    // <<0b01:2, size:unsigned-big-14, rest:bits>> -> Ok(#(size, rest|> bit_array.to_string|> result.unwrap("")|> string.drop_left(1)))
    // <<0b10:2, _ignore:6, size:unsigned-big-32, rest:bits>> ->
    //   Ok(#(size, rest))
    // <<0xC0, rest:bits>> -> Ok(#(8, rest))
    // <<0xC1, rest:bits>> -> Ok(#(16, rest))
    // <<0xC2, rest:bits>> -> Ok(#(32, rest))
    <<0xC3, _rest:bits>> -> Error("LZF compression isn't supported")
    _ -> Error("Invalid RDB size")
  } |> io.debug
}

fn get_chars(data, num_of_btyes) {
  let #(chars, rest) = get_bytes(data, num_of_btyes * 2)
  #(chars |> base16_to_char, rest)
}

fn get_word(data, num_of_btyes) {
  let #(chars, rest) = get_bytes(data, num_of_btyes * 2)
  #(chars, rest)
}

fn base16_to_char(base16) {
  let base16 =
    [base16]
    |> list.flatten
    |> list.sized_chunk(2)
    |> list.map(fn(x) { x |> string.join("") })
  let base16 =
    base16
    |> list.map(fn(x) {
      int.base_parse(x, 16)
      |> result.unwrap(0)
    })
  let codepoints =
    base16
    |> list.map(fn(x) {
      let assert Ok(y) = x |> string.utf_codepoint
      y
    })
  codepoints |> string.from_utf_codepoints
}

fn get_bytes(data, num_of_btyes) {
  let assert Ok(#(first_byte, rest)) = string.pop_grapheme(data)
  let #(bytes, rest) = case num_of_btyes {
    1 -> #([], rest)
    _ -> get_bytes(rest, num_of_btyes - 1)
  }
  #([first_byte, ..bytes], rest)
}
