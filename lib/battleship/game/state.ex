defmodule Battleship.Game.State do
  defstruct [:id, :phase, :timer_ref, :placement_deadline, :boards, :players]

  alias Battleship.Game.Core.Board

  def init(id, players, timer_ref \\ nil, placement_deadline \\ nil) do
    boards = Map.new(players, fn player_id -> {player_id, %Board{}} end)

    players =
      Map.new(players, fn player_id ->
        {player_id, %{connected: false, ready: false}}
      end)

    %__MODULE__{
      id: id,
      players: players,
      timer_ref: timer_ref,
      placement_deadline: placement_deadline,
      phase: :waiting_opponent,
      boards: boards
    }
  end

  def next_phase(%__MODULE__{phase: :waiting_opponent} = state),
    do: %{state | phase: :placement}

  def next_phase(%__MODULE__{phase: :placement} = state) do
    %__MODULE__{state | phase: :battle, timer_ref: nil, placement_deadline: nil}
  end

  def next_phase(%__MODULE__{phase: :battle} = state) do
    %__MODULE__{state | phase: :game_over}
  end

  def mark_connected(%__MODULE__{} = state, player_id),
    do: update_player(state, player_id, &Map.put(&1, :connected, true))

  def mark_ready(%__MODULE__{phase: :placement} = state, player_id),
    do: update_player(state, player_id, &Map.put(&1, :ready, true))

  def mark_ready(_state, _player_id), do: {:error, :not_placement_phase}

  def all_connected?(%__MODULE__{players: players}),
    do: Enum.all?(players, fn {_id, p} -> p.connected end)

  def all_ready?(%__MODULE__{players: players}),
    do: Enum.all?(players, fn {_id, p} -> p.ready end)

  defp update_player(%__MODULE__{players: players} = state, player_id, fun) do
    case Map.fetch(players, player_id) do
      {:ok, player} -> %{state | players: Map.put(players, player_id, fun.(player))}
      :error -> {:error, :unknown_player}
    end
  end
end
