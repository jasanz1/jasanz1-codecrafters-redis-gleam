import argv
import database_api
import birl
import birl/duration
import carpenter/table.{type Set}
import commands/config_cmd
import commands/echo_cmd
import commands/get_cmd
import commands/ping_cmd
import commands/set_cmd
import decoder.{decode}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import glisten
import state.{type State}

pub fn main() {
  // You can use print statements as follows for debugging, they'll be visible when running tests.
  let args = argv.load()
  let assert Ok(ets) =
    table.build("redis")
    |> table.privacy(table.Public)
    |> table.write_concurrency(table.WriteConcurrency)
    |> table.read_concurrency(True)
    |> table.compression(False)
    |> table.set
  let assert Ok(config) =
    table.build("config")
    |> table.privacy(table.Public)
    |> table.write_concurrency(table.WriteConcurrency)
    |> table.read_concurrency(True)
    |> table.compression(False)
    |> table.set
   let state = init_config(args, state.State(ets, config))
  io.println("Logs from your program will appear here!")
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(state, None) }, loop)
    |> glisten.serve(6379)

  process.sleep_forever()
}

fn loop(msg: glisten.Message(a), state: State, conn: glisten.Connection(a)) {
  let byte_message = case msg {
    glisten.Packet(x) -> x
    _ -> bytes_builder.to_bit_array(bytes_builder.from_string("Error"))
  }
  let message = bit_array.to_string(byte_message) |> result.unwrap("") |> decode
  let state = process_message(message, state, conn)
  actor.continue(state)
}

fn process_message(
  msg: List(String),
  state: State,
  conn: glisten.Connection(a),
) -> State {
  let send = fn(x) { glisten.send(conn, bytes_builder.from_string(x)) }
  let #(command, args) = case msg {
    [head, ..rest] -> #(head, rest)
    _ -> #("", [])
  }
  let assert Ok(state) = case command |> string.uppercase(), args {
    "", [] -> state |> Ok
    "PING", [] -> {
      let assert Ok(_) = send(ping_cmd.ping_cmd() |> io.debug)
      state |> Ok
    }
    "GET", [key, ..] -> {
      let response = get_cmd.get_cmd(state, key)
      let assert Ok(_) = send(response)
      state |> Ok
    }
    "ECHO", [echomsg, ..] -> {
      let assert Ok(_) = send(echo_cmd.echo_cmd(echomsg) |> io.debug)
      state |> Ok
    }
    // "KEYS", [pattern, ..] -> {
    //  let response = keys_cmd.keys_cmd(state, pattern)
    //   let assert Ok(_) = send(response |> io.debug)
    //   state |> Ok
    // }
    "SET", [key, value, ..rest] -> {
      let #(px, expiration, _rest) = case rest {
        [px, expiration, ..rest] -> #(px, expiration, rest)
        _ -> #("", "", [])
      }
      let response = case px |> string.uppercase() {
        "PX" -> {
          let expiration = expiration |> int.parse() |> result.unwrap(0)
          let expiration =
            birl.add(birl.now(), duration.milli_seconds(expiration))
          set_cmd.set_cmd(state, key, #(value, Some(expiration)))
        }
        _ -> set_cmd.set_cmd(state, key, #(value, None))
      }
      let assert Ok(_) = send(response |> io.debug)
      state |> Ok
    }
    "CONFIG", [sub_command, dir, ..] -> {
      let response = config_cmd.config_cmd(state, sub_command, dir)
      let assert Ok(_) = send(response |> io.debug)
      state |> Ok
    }
    _, _ -> {
      let _ = glisten.send(conn, bytes_builder.from_string("+Error\r\n"))
      state |> Error
    }
  }
  state
}

fn init_config(
  args: argv.Argv,
  state: State 
) ->State{
  do_init_config(args.arguments, state)
}

fn do_init_config(args, state:State) {
  case args {
    [] -> state
    ["--dir", filename, ..rest] -> {
      let _ = table.insert(state.config, [#("dir", [filename])])
      do_init_config(rest, state)
    }
    ["--dbfilename", filename, ..rest] -> {
      let _ = table.insert(state.config, [#("dbfilename", [filename])])
      database_api.load_database(filename, state)
      do_init_config(rest, state)
    }
    _ -> state
  }
}
