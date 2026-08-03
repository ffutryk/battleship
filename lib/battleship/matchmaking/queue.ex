defmodule Battleship.Matchmaking.Queue do
  use GenServer

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def join_queue(player_id, pid),
    do: GenServer.cast(__MODULE__, {:join_queue, player_id, pid})

  def leave_queue(player_id),
    do: GenServer.cast(__MODULE__, {:leave_queue, player_id})

  @impl true
  def init(_args) do
    {:ok, :queue.new()}
  end

  @impl true
  def handle_cast({:join_queue, player_id, pid}, state) do
    ref = Process.monitor(pid)

    {:noreply, process_join(:queue.out(state), {player_id, ref})}
  end

  @impl true
  def handle_cast({:leave_queue, player_id}, state) do
    {:noreply, process_leave(player_id, state)}
  end

  defp process_leave(player_id, queue) do
    :queue.filter(
      fn {queued_player_id, ref} ->
        if queued_player_id == player_id do
          Process.demonitor(ref, [:flush])
          false
        else
          true
        end
      end,
      queue
    )
  end

  defp process_join({:empty, queue}, player) do
    :queue.in(player, queue)
  end

  defp process_join({{:value, {opponent, opponent_ref}}, remaining}, {player_id, player_ref}) do
    Task.Supervisor.start_child(Battleship.TaskSupervisor, fn ->
      create_game([opponent, player_id])
    end)

    [player_ref, opponent_ref] |> Enum.each(&Process.demonitor(&1, [:flush]))

    remaining
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    new_queue =
      :queue.filter(
        fn {_player, player_ref} -> player_ref != ref end,
        state
      )

    {:noreply, new_queue}
  end

  defp create_game(player_ids) do
    game_id = System.unique_integer([:positive])

    case Battleship.Game.Supervisor.start_game(game_id, player_ids) do
      {:ok, _pid} -> notify_players(player_ids, {:match_found, game_id})
      {:error, reason} -> notify_players(player_ids, {:error, reason})
    end
  end

  defp notify_players(player_ids, message) do
    Enum.each(player_ids, &broadcast(&1, message))
  end

  defp broadcast(id, message) do
    Phoenix.PubSub.broadcast(Battleship.PubSub, "matchmaking:#{id}", message)
  end
end
