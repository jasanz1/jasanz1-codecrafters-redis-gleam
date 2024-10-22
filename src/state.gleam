import birl
import gleam/option

import carpenter/table.{type Set}

pub type State {

  State(data: Set(String, Entry), config: Set(String, List(String)))
}

type Entry =
  #(String, Expiry)

type Expiry =
  #(birl.Time, option.Option(Int))
