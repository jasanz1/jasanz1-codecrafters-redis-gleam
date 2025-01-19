import birl
import birl/duration
import carpenter/table
import gleam/bit_array
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
    expiry: Option(ExpiryType),
    value_type: EncodeType,
    key: String,
    value: String,
  )
}

type Size {
  Length(Int)
  Integer(Int)
}

pub fn load_database(database_name, state: State) {
  let assert Ok(database) =
    database_name |> string.lowercase() |> simplifile.read_bits
  let assert Ok(finished_db) =
    database |> read_header |> read_meta |> read_data |> read_checksum
  use data <- list.map(finished_db.data)
  use entry <- list.map(data.entries)
  case entry.expiry {
    None -> table.insert(state.data, [#(entry.key, #(entry.value, None))])
    Some(expiry) ->
      case expiry {
        Milliseconds(expiry) ->
          table.insert(state.data, [#(entry.key, #(entry.value, Some(expiry)))])

        Seconds(expiry) ->
          table.insert(state.data, [#(entry.key, #(entry.value, Some(expiry)))])
      }
  }
}

fn read_checksum(database) -> Result(Database, String) {
  let assert Ok(#(database, bits)) = database
  case bits {
    <<0xFF, rest:unsigned-size(64), _rest:bits>> ->
      Database(..database, checksum: rest) |> Ok
    _ -> Error("Failed at the checksum")
  }
}

fn read_data(database) -> Result(#(Database, BitArray), String) {
  let assert Ok(#(database, bits)) = database
  let assert Ok(#(data, rest)) = get_data(bits)
  Ok(#(Database(..database, data: data), rest))
}

fn get_data(bits) -> Result(#(List(Data), BitArray), String) {
  case bits {
    <<0xFE, rest:bits>> -> {
      let assert Ok(#(index, rest)) = size_decode(rest)
      let index = case index {
        Length(length) -> length
        Integer(length) -> length
      }
      let assert Ok(rest) = case rest {
        <<0xFB, rest:bits>> -> rest |> Ok
        _ -> {
          Error("Failed at the data: could not find start of hash size")
        }
      }

      let assert Ok(#(value_hash_size, rest)) = size_decode(rest)
      let assert Ok(#(expiry_hash_size, rest)) = size_decode(rest)
      let value_hash_size = case value_hash_size {
        Length(length) -> length
        Integer(length) -> length
      }
      let expiry_hash_size = case expiry_hash_size {
        Length(length) -> length
        Integer(length) -> length
      }
      let assert Ok(#(entries, rest)) = get_entries(rest)
      let assert Ok(#(data, rest)) = get_data(rest)
      #(
        [
          Data(
            index: index,
            value_hash_size: value_hash_size,
            expiry_hash_size: expiry_hash_size,
            entries: entries,
          ),
          ..data
        ],
        rest,
      )
      |> Ok
    }
    <<0xFF, _:bits>> -> #([], bits) |> Ok
    _ -> Error("Failed at the data")
  }
}

fn get_entries(bits) -> Result(#(List(Entry), BitArray), String) {
  let eight_byte_size = 8 * 8
  let four_byte_size = 4 * 8
  let #(entry, bits) = case bits {
    <<0xFC, expiry:unsigned-little-size(eight_byte_size), rest:bits>> -> #(
      Entry(Some(Milliseconds(birl.from_unix_milli(expiry))), String, "", ""),
      rest,
    )
    <<0xFD, expiry:unsigned-little-size(four_byte_size), rest:bits>> -> #(
      Entry(Some(Seconds(birl.from_unix(expiry))), String, "", ""),
      rest,
    )
    _ -> #(Entry(None, String, "", ""), bits)
  }
  case bits {
    <<0x00, rest:bits>> -> {
      let assert Ok(#(key, value, bits)) = get_key_value(rest)
      let assert Ok(#(entries, bits)) = get_entries(bits)
      #([Entry(..entry, key: key, value: value), ..entries], bits)
      |> Ok
    }
    <<0xFE, _:bits>> | <<0xFF, _:bits>> -> #([], bits) |> Ok
    _ -> Error("Failed at the data: could not find start of datachunk")
  }
}

fn get_key_value(bits) -> Result(#(String, String, BitArray), String) {
  let assert Ok(#(length, bits)) = size_decode(bits)
  let assert Ok(#(key, bits)) = string_read_length(length, bits)
  let assert Ok(#(length, bits)) = size_decode(bits)
  let assert Ok(#(value, bits)) = string_read_length(length, bits)
  #(key, value, bits) |> Ok
}

fn read_meta(database) -> Result(#(Database, BitArray), String) {
  let assert Ok(#(database, bits)) = database
  let assert Ok(#(metadata, rest)) = case bits {
    <<0xFA, rest:bits>> -> get_metadata(rest, dict.new())
    _ -> Error("Failed at the meta")
  }
  Ok(#(Database(..database, meta: metadata), rest))
}

fn get_metadata(
  bits,
  metadata,
) -> Result(#(Dict(String, String), BitArray), String) {
  let assert Ok(#(key, value, bits)) = get_key_value(bits)
  let assert Ok(#(metadata, bits)) = case bits {
    <<0xFE, _rest:bits>> -> #(metadata |> dict.insert(key, value), bits) |> Ok
    <<0xFA, rest:bits>> ->
      get_metadata(rest, metadata |> dict.insert(key, value))
    _ -> Error("Failed at the meta: could not find the end of the metadata")
  }
  Ok(#(metadata, bits))
}

fn string_read_length(length, bits) -> Result(#(String, BitArray), String) {
  case length {
    Length(length) -> {
      let assert Ok(#(key, bits)) = read_bytes(bits, length)
      Ok(#(key |> bit_array.to_string |> result.unwrap(""), bits))
    }
    Integer(length) -> {
      let return = case bits {
        <<integer:size(length)-unsigned-little, rest:bits>> ->
          #(int.to_string(integer), rest) |> Ok
        _ -> Error("Failed to parse integer")
      }
      return
    }
  }
}

fn size_decode(bits) -> Result(#(Size, BitArray), String) {
  case bits {
    <<00:2, size:6, rest:bits>> -> #(Length(size), rest) |> Ok
    <<01:2, size:14, rest:bits>> -> #(Length(size), rest) |> Ok
    <<10:2, _:6, size:int-size(4), rest:bits>> -> #(Length(size), rest) |> Ok
    <<0xC0, rest:bits>> -> Ok(#(Integer(8), rest))
    <<0xC1, rest:bits>> -> Ok(#(Integer(16), rest))
    <<0xC2, rest:bits>> -> Ok(#(Integer(32), rest))
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
