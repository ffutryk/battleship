defmodule Battleship.Matchmaking.Supervisor do
  use Supervisor

  alias Battleship.Matchmaking.Queue

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg), do: Supervisor.init([Queue], strategy: :one_for_one)
end
