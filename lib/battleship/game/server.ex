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

  def get_state(game_id) do
    case GenServer.whereis(GameRegistry.via_tuple(game_id)) do
      nil -> nil
      pid -> GenServer.call(pid, :get_state)
    end
  end

  def connect(game_id, player_id, pid) do
    GenServer.call(GameRegistry.via_tuple(game_id), {:player_connected, player_id, pid})
  end

  def place_ship(game_id, player_id, coords) do
    GenServer.call(GameRegistry.via_tuple(game_id), {:place_ship, player_id, coords})
  end

  def confirm_placement(game_id, player_id) do
    GenServer.call(GameRegistry.via_tuple(game_id), {:confirm_placement, player_id})
  end

  @impl true
  def init({game_id, players}) do
    {:ok, State.init(game_id, players)}
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

  @impl true
  def handle_call({:place_ship, _, _}, _from, state) do
    {:reply, {:error, :not_placement_phase}, state}
  end

  @impl true
  def handle_call({:confirm_placement, player_id}, _from, %State{phase: :placement} = state) do
    board = Map.fetch!(state.boards, player_id)

    if Board.ready?(board) do
      new_state = State.mark_ready(state, player_id)

      if State.all_ready?(new_state) do
        {:reply, :ok, progress(new_state)}
      else
        {:reply, :ok, new_state}
      end
    else
      {:reply, {:error, :incomplete_placement}, state}
    end
  end

  @impl true
  def handle_call({:confirm_placement, _player_id}, _from, state) do
    {:reply, {:error, :not_placement_phase}, state}
  end

  @impl true
  def handle_call({:player_connected, player_id, pid}, _from, state) do
    Process.monitor(pid)

    case State.mark_connected(state, player_id) do
      {:error, _} = error ->
        {:reply, error, state}

      connected_state ->
        new_state =
          if can_progress_to_placement?(connected_state) do
            progress(connected_state)
          else
            connected_state
          end

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_info(:placement_timeout, %State{phase: :placement} = state) do
    {:noreply, progress(state)}
  end

  @impl true
  def handle_info(:placement_timeout, state), do: {:noreply, state}

  defp progress(%State{phase: :waiting_opponent} = state) do
    timer_ref = Process.send_after(self(), :placement_timeout, @placement_timeout)
    remaining_ms = Process.read_timer(timer_ref)

    broadcast(state.id, {:phase_changed, :placement, remaining_ms})

    state
    |> Map.put(:timer_ref, timer_ref)
    |> State.next_phase()
  end

  defp progress(%State{phase: :placement} = state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    boards = Map.new(state.boards, fn {id, board} -> {id, Board.fill_random(board)} end)

    broadcast(state.id, {:phase_changed, :battle})

    state
    |> Map.put(:boards, boards)
    |> Map.put(:timer_ref, nil)
    |> State.next_phase()
  end

  defp broadcast(id, message), do: Phoenix.PubSub.broadcast(Battleship.PubSub, topic(id), message)
  defp topic(id), do: "game:#{id}"

  defp can_progress_to_placement?(%State{phase: phase, timer_ref: timer} = state),
    do: phase == :waiting_opponent and is_nil(timer) and State.all_connected?(state)
end
