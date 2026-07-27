defmodule Battleship.Matchmaking.Queue do
  use GenServer

  alias Battleship.Game.Coordinator

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def join_queue(player), do: GenServer.cast(__MODULE__, {:join_queue, player})

  @impl true
  def init(_args) do
    {:ok, :queue.new()}
  end

  @impl true
  def handle_cast({:join_queue, player}, state),
    do: {:noreply, process_join(:queue.out(state), player)}

  defp process_join({:empty, queue}, player) do
    :queue.in(player, queue)
  end

  defp process_join({{:value, opponent}, remaining}, player) do
    Coordinator.create_game([opponent, player])
    remaining
  end
end
