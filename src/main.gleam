import commands/ping
import gleam/bit_array
import gleam/bytes_builder
import gleam/io
import gleam/result
import gleam/string

import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten

pub fn main() {
  // You can use print statements as follows for debugging, they'll be visible when running tests.
  io.println("Logs from your program will appear here!")
  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, loop)
    |> glisten.serve(6379)

  process.sleep_forever()
}

fn loop(msg: glisten.Message(a), state: state, conn: glisten.Connection(a)) {
  let byte_message = case msg {
    glisten.Packet(x) -> x
    _ -> bytes_builder.to_bit_array(bytes_builder.from_string("Error"))
  }

  let message =
    bit_array.to_string(byte_message)
    |> result.unwrap("Error")
    |> string.split(";")

  process_message(message, state, conn)
  actor.continue(state)
}

fn process_message(msg: List(String), state: state, conn: glisten.Connection(a)) {
  let assert Ok(return) = case msg {
    [] -> [] |> Ok
    ["PING", ..rest] ->
      [
        glisten.send(conn, bytes_builder.from_string(ping.ping())),
        ..process_message(rest, state, conn)
      ]
      |> Ok
    _ ->
      [
        glisten.send(conn, bytes_builder.from_string("Error")),
        ..process_message(msg, state, conn)
      ]
      |> Error
  }
  return
}
