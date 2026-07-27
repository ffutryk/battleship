defmodule Battleship.Game.Server do
  use GenServer

  alias Battleship.Game.State
  alias Battleship.Game.Registry, as: GameRegistry

  def start_link({game_id, players}) do
    GenServer.start_link(__MODULE__, {game_id, players}, name: GameRegistry.via_tuple(game_id))
  end

  def get_state(game_id), do: GenServer.call(GameRegistry.via_tuple(game_id), :get_state)

  @impl true
  def init({game_id, players}), do: {:ok, %State{id: game_id, players: players}}

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}
end
