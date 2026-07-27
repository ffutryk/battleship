defmodule Battleship.Matchmaking.Queue do
  use GenServer

  alias Battleship.Game.Coordinator

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def join_queue(player), do: GenServer.cast(__MODULE__, {:join_queue, player})

  @impl true
  def init(_args) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:join_queue, player}, []), do: {:noreply, [player]}

  @impl true
  def handle_cast({:join_queue, player}, [opponent | remaining]) do
    Coordinator.create_game([player, opponent])
    {:noreply, remaining}
  end
end
