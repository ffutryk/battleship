defmodule Battleship.Game.Server do
  use GenServer

  alias Battleship.Game.State
  alias Battleship.Game.Registry, as: GameRegistry

  @placement_seconds 30
  @placement_timeout :timer.seconds(@placement_seconds)

  def start_link({game_id, players}) do
    GenServer.start_link(__MODULE__, {game_id, players}, name: GameRegistry.via_tuple(game_id))
  end

  def get_state(game_id), do: GenServer.call(GameRegistry.via_tuple(game_id), :get_state)

  @impl true
  def init({game_id, players}) do
    timer_ref = Process.send_after(self(), :placement_timeout, @placement_timeout)
    placement_deadline = System.monotonic_time(:second) + @placement_seconds

    state = State.init(game_id, players, timer_ref, placement_deadline)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_info(:placement_timeout, state), do: {:noreply, state}
end
