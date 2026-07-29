defmodule Battleship.Game.State do
  defstruct [
    :id,
    :players,
    :phase,
    :timer_ref,
    :placement_deadline,
    :boards
  ]

  alias Battleship.Game.Core.Board

  def init(id, players, timer_ref, placement_deadline) do
    boards = Map.new(players, &{&1.id, %Board{}})

    %__MODULE__{
      id: id,
      players: players,
      timer_ref: timer_ref,
      placement_deadline: placement_deadline,
      phase: :placement,
      boards: boards
    }
  end

  def next_phase(%__MODULE__{phase: :placement} = state) do
    %__MODULE__{state | phase: :battle, timer_ref: nil, placement_deadline: nil}
  end

  def next_phase(%__MODULE__{phase: :battle} = state) do
    %__MODULE__{state | phase: :game_over}
  end
end
