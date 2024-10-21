import encoder
pub fn get_cmd(key) -> String {
case key {
  "foo" -> "bar"
  _ -> "baz"
  } |> encoder.encode_bulk_string
}
