import encoder
import gleam/dict
pub fn get_cmd(my_dict, key) -> String {
  let assert Ok(value) = dict.get(my_dict, key)
  encoder.encode_simple_string(value)
}
