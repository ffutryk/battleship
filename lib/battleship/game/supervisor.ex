defmodule Battleship.Game.Supervisor do
  use DynamicSupervisor

  alias Battleship.Game.Server

  def start_link(_arg), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_game(game_id, player_ids) do
    child_spec =
      Supervisor.child_spec(
        {Server, {game_id, player_ids}},
        restart: :transient
      )

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
