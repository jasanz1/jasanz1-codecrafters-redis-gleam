import carpenter/table
import encoder
import birl
import gleam/order.{Gt}
import birl/duration
import gleam/option.{Some,None}
pub fn get_cmd(my_table, key) -> String {
  let assert [#(_, #(value, #(set_date, expiration)))] =
    table.lookup(my_table, key)

  case expiration {
    None -> encoder.encode_bulk_string(Some(value))
    Some(expiration) -> {
      let expire = birl.add(set_date,duration.milli_seconds(expiration))
      case birl.compare(birl.now(), expire) {
        Gt -> encoder.encode_bulk_string(None)
        _ -> encoder.encode_bulk_string(Some(value))
      }
    }
  }
}
