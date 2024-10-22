import carpenter/table
import encoder
import gleam/option.{Some}
import state.{type State}

pub fn set_cmd(my_table: State, key, value) -> String {
  table.insert(my_table.data, [#(key, value)])
  encoder.encode_simple_string(Some("OK"))
}
