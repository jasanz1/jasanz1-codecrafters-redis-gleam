import carpenter/table
import encoder
import birl
import birl/duration
import gleam/option.{Some,None}
pub fn get_cmd(my_table, key) -> String {
  let assert [#(_, #(value, #(setDate, expiration)))] =
    table.lookup(my_table, key)

  case expiration {
    None -> value
    Some(expiration) -> {
      let expire = birl.add(duration.from_seconds(expiration), setDate)
      case birl.compare(birl.now(), expire) {
        Gt -> encoder.encode_bulk_string(None)
        _ -> encoder.encode_simple_string(value)
      }
    }
  }
}
