import birl
import carpenter/table
import encoder
import gleam/option.{None, Some}
import gleam/order.{Gt}
import state.{type State}

pub fn get_cmd(my_table: State, key) -> String {
  let assert [#(_, #(value, expiration))] = table.lookup(my_table.data, key)

  case expiration {
    None -> encoder.encode_bulk_string(Some(value))
    Some(expiration) -> {
      case birl.compare(birl.now(), expiration) {
        Gt -> encoder.encode_bulk_string(None)
        _ -> encoder.encode_bulk_string(Some(value))
      }
    }
  }
}
