import commands/ping
import gleam/bytes_builder
import gleam/io

import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten

pub fn main() {

  // You can use print statements as follows for debugging, they'll be visible when running tests.
  io.println("Logs from your program will appear here!")
  let assert Ok(_) =
  glisten.handler(fn(_conn) { #(Nil, None) }, loop )
  |> glisten.serve(6379)

  process.sleep_forever()
}
fn loop(_msg: glisten.Message(a), state: state, conn: glisten.Connection(a)) {
  // let string_to_bitarray = fn(x) { bytes_builder.from_string(x) |> bytes_builder.to_bit_array()}
  let assert Ok(_)= glisten.send(conn,bytes_builder.from_string(ping.ping()))
  actor.continue(state)
}
