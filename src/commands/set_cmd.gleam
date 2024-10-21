import carpenter/table
import encoder

pub fn set_cmd(my_table, key, value) -> String {
  table.insert(my_table, [#(key, value)])
  encoder.encode_simple_string("OK")
}
