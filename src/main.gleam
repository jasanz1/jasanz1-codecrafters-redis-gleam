import carpenter/table.{type Set}
import commands/echo_cmd
import commands/get_cmd
import commands/ping_cmd
import commands/set_cmd
import decoder.{decode}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/io
import gleam/option.{None}
import gleam/otp/actor
import gleam/result
import glisten

type State =
  Set(String, String)

pub fn main() {
  // You can use print statements as follows for debugging, they'll be visible when running tests.
  let assert Ok(ets) =
    table.build("redis")
    |> table.privacy(table.Public)
    |> table.write_concurrency(table.WriteConcurrency)
    |> table.read_concurrency(True)
    |> table.compression(False)
    |> table.set

  io.println("Logs from your program will appear here!")
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(ets, None) }, loop)
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

  let assert Ok(state) = case msg {
    [] -> state |> Ok
    ["PING", ..rest] -> {
      let assert Ok(_) = send(ping_cmd.ping_cmd() |> io.debug)
      state |> Ok
    }
    ["ECHO", echomsg, ..rest] -> {
      let assert Ok(_) = send(echo_cmd.echo_cmd(echomsg) |> io.debug)
      state |> Ok
    }
    ["SET", key, value, ..rest] -> {
      let response = set_cmd.set_cmd(state, key, value)
      let assert Ok(_) = send(response |> io.debug)
      state |> Ok
    }
    ["GET", key, ..rest] -> {
      let assert Ok(_) = send(get_cmd.get_cmd(state, key) |> io.debug)
      state |> Ok
    }
    _ -> {
      glisten.send(conn, bytes_builder.from_string("Error"))
      state |> Error
    }
  }
  state
}
