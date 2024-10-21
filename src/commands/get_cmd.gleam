import carpenter/table
import encoder

pub fn get_cmd(my_table, key) -> String {
  let assert [#(_, value)] = table.lookup(my_table, key)
  encoder.encode_simple_string(value)
}
