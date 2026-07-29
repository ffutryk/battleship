defmodule Battleship.Game.State do
  defstruct [
    :id,
    :players,
    :phase,
    :timer_ref,
    :placement_deadline,
    :boards,
    :ready
  ]

  alias Battleship.Game.Core.Board

  def init(id, players, timer_ref, placement_deadline) do
    boards = Map.new(players, &{&1.id, %Board{}})
    ready = Map.new(players, &{&1.id, false})

    %__MODULE__{
      id: id,
      players: players,
      timer_ref: timer_ref,
      placement_deadline: placement_deadline,
      phase: :placement,
      boards: boards,
      ready: ready
    }
  end

  def next_phase(%__MODULE__{phase: :placement} = state) do
    %__MODULE__{state | phase: :battle, timer_ref: nil, placement_deadline: nil}
  end

  def next_phase(%__MODULE__{phase: :battle} = state) do
    %__MODULE__{state | phase: :game_over}
  end

  def mark_ready(%__MODULE__{phase: :placement} = state, player_id) do
    %{state | ready: Map.put(state.ready, player_id, true)}
  end

  def mark_ready(_state, _player_id), do: {:error, :not_placement_phase}

  def all_ready?(%__MODULE__{ready: ready}), do: Enum.all?(ready, fn {_id, r} -> r end)
end
