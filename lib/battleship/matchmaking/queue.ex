defmodule Battleship.Matchmaking.Queue do
  use GenServer

  alias Battleship.Game.Bot

  @wait_before_bot :timer.seconds(15)

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
    entry = %{
      player_id: player_id,
      monitor_ref: Process.monitor(pid),
      bot_timer_ref: Process.send_after(self(), {:bot_matchmaking, player_id}, @wait_before_bot)
    }

    {:noreply, process_join(:queue.out(state), entry)}
  end

  @impl true
  def handle_cast({:leave_queue, player_id}, state) do
    {:noreply, process_leave(player_id, state)}
  end

  defp process_leave(player_id, queue) do
    :queue.filter(
      fn entry ->
        if entry.player_id == player_id do
          Process.demonitor(entry.monitor_ref, [:flush])
          cancel_bot_timer(entry)
          false
        else
          true
        end
      end,
      queue
    )
  end

  defp process_join({:empty, queue}, entry), do: :queue.in(entry, queue)

  defp process_join({{:value, opponent}, remaining}, player) do
    Task.Supervisor.start_child(Battleship.TaskSupervisor, fn ->
      create_game([opponent.player_id, player.player_id])
    end)

    Process.demonitor(opponent.monitor_ref, [:flush])
    Process.demonitor(player.monitor_ref, [:flush])
    cancel_bot_timer(opponent)
    cancel_bot_timer(player)

    remaining
  end

  @impl true
  def handle_info({:bot_matchmaking, player_id}, state) do
    if queued?(state, player_id) do
      new_state = process_leave(player_id, state)
      create_game([player_id], Bot.gen_id())
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    new_queue =
      :queue.filter(
        fn entry ->
          if entry.monitor_ref == ref do
            cancel_bot_timer(entry)
            false
          else
            true
          end
        end,
        state
      )

    {:noreply, new_queue}
  end

  defp create_game(player_ids, bot_id \\ nil) do
    game_id = System.unique_integer([:positive])

    case Battleship.Game.Supervisor.start_game(game_id, player_ids, bot_id) do
      {:ok, _pid} -> notify_players(player_ids, {:match_found, game_id})
      {:error, reason} -> notify_players(player_ids, {:error, reason})
    end
  end

  defp queued?(queue, player_id) do
    queue |> :queue.to_list() |> Enum.any?(&(&1.player_id == player_id))
  end

  defp cancel_bot_timer(%{bot_timer_ref: ref}), do: Process.cancel_timer(ref)

  defp notify_players(player_ids, message) do
    Enum.each(player_ids, &broadcast(&1, message))
  end

  defp broadcast(id, message) do
    Phoenix.PubSub.broadcast(Battleship.PubSub, "matchmaking:#{id}", message)
  end
end
