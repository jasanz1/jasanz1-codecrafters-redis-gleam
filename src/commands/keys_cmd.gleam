import carpenter/table
import encoder
import gleam/io
import gleam/list
import state.{type Entry, type State}

pub fn keys_cmd(state: State, key) -> String {
  let keys =
    table.lookup(state.data, key) |> list.map(fn(x: #(String, Entry)) { x.0 })
  keys |> io.debug
  encoder.encode_array(keys, encoder.encode_simple_string)
}
