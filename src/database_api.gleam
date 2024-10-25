import gleam/io
import birl
import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
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
    database_name |> string.lowercase() |> simplifile.read
  let assert Ok(base_data) = database |> get_header 
}
 fn get_header(data){
  get_bytes(data,4) |> io.debug |> Ok
}



fn get_bytes(data,num_of_btyes){
  let assert Ok(#(first_byte,rest)) = string.pop_grapheme(data)
  let #(bytes,rest) = case num_of_btyes{
    0 -> #("",data)
    _ -> get_bytes(rest,num_of_btyes - 1)
  }
  #(first_byte<>bytes, rest)
}
