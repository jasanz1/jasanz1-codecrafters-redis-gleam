import state.{type State ,type Entry}
import carpenter/table
import encoder
import gleam/list
pub fn keys_cmd(state: State, key) -> String {
  
let keys = table.lookup(state.data, key) |> list.map(fn(x: #(String,Entry)) { x.0 })
 encoder.encode_array(keys, encoder.encode_simple_string)
}
