import carpenter/table.{type Set}
import encoder
import gleam/string
import state.{type State}

pub fn config_cmd(state: State, sub_command, dir) {
  case
    sub_command
    |> string.uppercase()
  {
    "GET" -> get_config(state.config, dir)
    _ -> "Error"
  }
}

fn get_config(config: Set(String, List(String)), dir) {
  let lookup = case dir |> string.uppercase {
    "DIR" -> table.lookup(config, "dir")
    "DBFILENAME" -> table.lookup(config, "dbfilename")
    _ -> [#("", [])]
  }
  let assert Ok(#(config_name, config_value)) = case lookup {
    [] -> #("", []) |> Ok
    [#(y, x)] -> #(y, x) |> Ok
    _ -> Nil |> Error
  }
  [config_name, ..config_value]
  |> encoder.encode_array(encoder.encode_bulk_string)
}
