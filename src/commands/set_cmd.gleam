import encoder
import gleam/dict
pub fn set_cmd(my_dict, key, value) -> #(dict.Dict(String, String), String) {
  #(dict.insert(my_dict, key, value), encoder.encode_simple_string("OK"))
}
