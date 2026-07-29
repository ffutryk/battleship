defmodule Battleship.Game.Server do
  use GenServer

  alias Battleship.Game.State
  alias Battleship.Game.Core.Board
  alias Battleship.Game.Registry, as: GameRegistry

  @placement_seconds 30
  @placement_timeout :timer.seconds(@placement_seconds)

  def start_link({game_id, players}) do
    GenServer.start_link(__MODULE__, {game_id, players}, name: GameRegistry.via_tuple(game_id))
  end

  def get_state(game_id), do: GenServer.call(GameRegistry.via_tuple(game_id), :get_state)

  def place_ship(game_id, player_id, coords) do
    GenServer.call(GameRegistry.via_tuple(game_id), {:place_ship, player_id, coords})
  end

  def confirm_placement(game_id, player_id) do
    GenServer.call(GameRegistry.via_tuple(game_id), {:confirm_placement, player_id})
  end

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
  def handle_call({:place_ship, player_id, coords}, _from, %State{phase: :placement} = state) do
    board = Map.fetch!(state.boards, player_id)

    case Board.place_ship(board, coords) do
      {:ok, updated_board} ->
        new_state = %{state | boards: Map.put(state.boards, player_id, updated_board)}
        {:reply, {:ok, updated_board}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:place_ship, _, _}, _from, state) do
    {:reply, {:error, :not_placement_phase}, state}
  end

  def handle_call({:confirm_placement, player_id}, _from, %State{phase: :placement} = state) do
    board = Map.fetch!(state.boards, player_id)

    if Board.ready?(board) do
      new_state = State.mark_ready(state, player_id)

      if State.all_ready?(new_state) do
        {:reply, :ok, start_battle(new_state)}
      else
        {:reply, :ok, new_state}
      end
    else
      {:reply, {:error, :incomplete_placement}, state}
    end
  end

  def handle_call({:confirm_placement, _player_id}, _from, state) do
    {:reply, {:error, :not_placement_phase}, state}
  end

  @impl true
  def handle_info(:placement_timeout, %State{phase: :placement} = state) do
    {:noreply, start_battle(state)}
  end

  @impl true
  def handle_info(:placement_timeout, state), do: {:noreply, state}

  defp start_battle(state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    boards = Map.new(state.boards, fn {id, board} -> {id, Board.fill_random(board)} end)

    Phoenix.PubSub.broadcast(Battleship.PubSub, "game:#{state.id}", {:phase_changed, :battle})

    %{state | boards: boards, timer_ref: nil} |> State.next_phase()
  end
end
