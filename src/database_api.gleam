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

pub opaque type Database {
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

    read_header(database)
  |> io.debug()
    |> read_meta
    |> io.debug()
  database
}
fn read_meta(database) -> Result(#(Database, BitArray), String) {
let assert Ok(#(database, bits)) = database
 let assert Ok(#(metadata,rest)) = case bits {
    <<0xFA , rest:bits>> -> get_metadata(rest)
    _ -> Error("Failed at the meta")
  }
  Ok(#(Database(..database, meta:metadata), rest))
}
fn get_metadata(bits) -> Result(#(Dict(String, String), BitArray), String) {
  let assert Ok(#(length,bits)) = string_length_decode(bits)
  let assert Ok(#(key,bits)) = read_bytes(bits, length)
  
  let assert Ok(#(length,bits)) = string_length_decode(bits)
  let assert Ok(#(value,bits)) = read_bytes(bits, length)

  todo
}

fn string_length_decode(bits) -> Result(#(Int, BitArray), String) {
  case bits {
    <<00:2, size:6, rest:bits>> -> #(size, rest) |> Ok
    <<01:2, size:14, rest:bits>> -> #(size, rest) |> Ok
    <<10:2,_:6, size:int-size(4), rest:bits>> -> #(size, rest) |> Ok
    <<11:2,_:6, size:bytes-size(8), rest:bits>> -> todo 
    _ -> Error("Failed at the string decode")
  }
}
fn read_header(database) -> Result(#(Database, BitArray), String) {
  case database {
    <<
      "REDIS":utf8,
      v0:utf8_codepoint,
      v1:utf8_codepoint,
      v2:utf8_codepoint,
      v3:utf8_codepoint,
      rest:bits,
    >> ->
      Ok(#(
        Database(
          "REDIS",
          string.from_utf_codepoints([v0, v1, v2, v3])
            |> int.parse()
            |> result.unwrap(0),
          dict.new(),
          [],
          0,
        ),
        rest,
      ))
    _ -> Error("Failed at the header")
  }
}

fn read_char_as_bytes(bits, size) -> Result(#(BitArray, BitArray), BitArray) {
  read_bytes(bits, size * 2)
}

fn read_bytes(bits, size) -> Result(#(BitArray, BitArray), BitArray) {
  case bits {
    <<bytes:bytes-size(size), rest:bits>> -> Ok(#(bytes, rest))
    _ -> Error(bits)
  }
}
