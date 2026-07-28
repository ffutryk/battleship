defmodule Battleship.Matchmaking.Queue do
  use GenServer

  alias Battleship.Game.Coordinator

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def join_queue(player, pid),
    do: GenServer.cast(__MODULE__, {:join_queue, player, pid})

  def leave_queue(player),
    do: GenServer.cast(__MODULE__, {:leave_queue, player})

  @impl true
  def init(_args) do
    {:ok, :queue.new()}
  end

  @impl true
  def handle_cast({:join_queue, player, pid}, state) do
    ref = Process.monitor(pid)

    {:noreply, process_join(:queue.out(state), {player, ref})}
  end

  @impl true
  def handle_cast({:leave_queue, player}, state) do
    {:noreply, process_leave(player, state)}
  end

  defp process_leave(player, queue) do
    :queue.filter(
      fn {queued_player, ref} ->
        if queued_player.id == player.id do
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

  defp process_join({{:value, {opponent, opponent_ref}}, remaining}, {player, player_ref}) do
    Coordinator.create_game([opponent, player])

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
end
