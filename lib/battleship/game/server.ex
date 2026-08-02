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

  def view(game_id, player_id) do
    case GenServer.whereis(GameRegistry.via_tuple(game_id)) do
      nil -> {:error, :game_not_found}
      pid -> GenServer.call(pid, {:view, player_id})
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

  def shoot_at(game_id, shooter_id, shot_coords) do
    GenServer.call(GameRegistry.via_tuple(game_id), {:shoot_at, shooter_id, shot_coords})
  end

  @impl true
  def init({game_id, players}) do
    {:ok, State.init(game_id, players)}
  end

  @impl true
  def handle_call({:view, player_id}, _from, state) do
    if Map.has_key?(state.players, player_id) do
      view = build_view(state, player_id)
      {:reply, {:ok, view}, state}
    else
      {:reply, {:error, :not_allowed}, state}
    end
  end

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
  def handle_call({:shoot_at, shooter_id, shot_coords}, _from, %State{phase: :battle} = state) do
    with :ok <- validate_turn(state, shooter_id),
         {:ok, opponent_id, updated_board, shot_state} <-
           fire_shot(state, shooter_id, shot_coords) do
      new_state = put_board(state, opponent_id, updated_board)

      broadcast(state.id, {:shot, shooter_id, opponent_id, shot_coords, shot_state})

      {:reply, shot_state, progress(new_state)}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:shoot_at, _, _}, _from, state) do
    {:reply, {:error, :not_battle_phase}, state}
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

  defp progress(%State{phase: :battle} = state) do
    if Enum.any?(state.boards, fn {_id, board} -> Board.all_sunken?(board) end) do
      new_state = State.next_phase(state)
      broadcast(state.id, {:phase_changed, :game_over, new_state.winner_id})
      new_state
    else
      State.next_turn(state)
    end
  end

  defp build_view(state, player_id) do
    player_board = state.boards[player_id]
    opponent_board = State.opponent_board(state, player_id)

    %{
      game_id: state.id,
      phase: state.phase,
      player_board: state.boards[player_id],
      player_shots: Board.shot_results(opponent_board),
      enemy_shots: Board.shot_results(player_board),
      is_turn?: state.battle_turn == player_id
    }
    |> maybe_put_remaining_ms(state)
    |> maybe_put_winner(state)
  end

  defp fire_shot(state, shooter_id, shot_coords) do
    opponent_id = State.opponent_id(state, shooter_id)
    board = Map.fetch!(state.boards, opponent_id)

    case Board.receive_shot(board, shot_coords) do
      {:error, _} = error -> error
      {updated_board, shot_state} -> {:ok, opponent_id, updated_board, shot_state}
    end
  end

  defp validate_turn(%State{battle_turn: battle_turn}, shooter_id) do
    if shooter_id == battle_turn, do: :ok, else: {:error, :not_allowed}
  end

  defp put_board(state, player_id, board) do
    %{state | boards: Map.put(state.boards, player_id, board)}
  end

  defp maybe_put_remaining_ms(view, %State{phase: :placement, timer_ref: ref})
       when not is_nil(ref),
       do: Map.put(view, :remaining_ms, Process.read_timer(ref) || 0)

  defp maybe_put_remaining_ms(view, _state), do: view

  defp maybe_put_winner(view, %State{phase: :game_over, winner_id: winner_id}),
    do: Map.put(view, :winner_id, winner_id)

  defp maybe_put_winner(view, _state), do: view

  defp broadcast(id, message), do: Phoenix.PubSub.broadcast(Battleship.PubSub, topic(id), message)
  defp topic(id), do: "game:#{id}"

  defp can_progress_to_placement?(%State{phase: phase, timer_ref: timer} = state),
    do: phase == :waiting_opponent and is_nil(timer) and State.all_connected?(state)
end
