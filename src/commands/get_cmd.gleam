import birl
import birl/duration
import carpenter/table
import encoder
import gleam/option.{None, Some}
import gleam/order.{Gt}
import state.{type State}

pub fn get_cmd(my_table: State, key) -> String {
  let assert [#(_, #(value, #(set_date, expiration)))] =
    table.lookup(my_table.data, key)

  case expiration {
    None -> encoder.encode_bulk_string(Some(value))
    Some(expiration) -> {
      let expire = birl.add(set_date, duration.milli_seconds(expiration))
      case birl.compare(birl.now(), expire) {
        Gt -> encoder.encode_bulk_string(None)
        _ -> encoder.encode_bulk_string(Some(value))
      }
    }
  }
}
