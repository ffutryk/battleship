defmodule Battleship.Matchmaking.QueueTest do
  use ExUnit.Case, async: false

  alias Battleship.Matchmaking.Queue
  alias Battleship.Game.Registry, as: GameRegistry

  describe "join_queue/2" do
    test "matches two waiting players into the same game and notifies both" do
      p1 = unique_player_id()
      p2 = unique_player_id()
      subscribe(p1)
      subscribe(p2)

      join(p1)
      join(p2)

      assert_receive {:match_found, game_id_1}, 1000
      assert_receive {:match_found, game_id_2}, 1000
      assert game_id_1 == game_id_2

      cleanup_game(game_id_1)
    end

    test "keeps a lone player waiting until the bot timeout fires" do
      p1 = unique_player_id()
      subscribe(p1)

      join(p1)

      refute_receive {:match_found, _game_id}, 200

      send(Queue, {:bot_matchmaking, p1})

      assert_receive {:match_found, game_id}, 1000

      cleanup_game(game_id)
    end

    test "matches players in FIFO order, leaving extra players waiting" do
      p1 = unique_player_id()
      p2 = unique_player_id()
      p3 = unique_player_id()
      subscribe(p1)
      subscribe(p2)
      subscribe(p3)

      join(p1)
      join(p2)
      join(p3)

      assert_receive {:match_found, game_id_1}, 1000
      assert_receive {:match_found, game_id_2}, 1000
      assert game_id_1 == game_id_2

      refute_receive {:match_found, _game_id}, 200

      cleanup_game(game_id_1)
    end
  end

  describe "leave_queue/1" do
    test "a player who leaves is not matched with a later joiner" do
      p1 = unique_player_id()
      p2 = unique_player_id()
      subscribe(p1)
      subscribe(p2)

      join(p1)
      Queue.leave_queue(p1)

      join(p2)

      refute_receive {:match_found, _game_id}, 300
    end

    test "a stale bot-matchmaking message has no effect after leaving" do
      p1 = unique_player_id()
      subscribe(p1)

      join(p1)
      Queue.leave_queue(p1)

      send(Queue, {:bot_matchmaking, p1})

      refute_receive {:match_found, _game_id}, 300
    end
  end

  describe "disconnection" do
    test "removes a queued player once its monitored process goes down" do
      p1 = unique_player_id()
      p2 = unique_player_id()
      subscribe(p1)
      subscribe(p2)

      dummy_pid = spawn(fn -> Process.sleep(:infinity) end)
      watcher_ref = Process.monitor(dummy_pid)

      Queue.join_queue(p1, dummy_pid)
      on_exit(fn -> Queue.leave_queue(p1) end)

      Process.exit(dummy_pid, :kill)
      assert_receive {:DOWN, ^watcher_ref, :process, ^dummy_pid, _reason}, 1000

      _ = :sys.get_state(Queue)

      join(p2)

      refute_receive {:match_found, _game_id}, 300
    end
  end

  defp unique_player_id, do: "player-" <> Integer.to_string(System.unique_integer([:positive]))

  defp subscribe(player_id) do
    Phoenix.PubSub.subscribe(Battleship.PubSub, "matchmaking:#{player_id}")
  end

  defp join(player_id, pid \\ self()) do
    Queue.join_queue(player_id, pid)
    on_exit(fn -> Queue.leave_queue(player_id) end)
  end

  defp cleanup_game(game_id) do
    on_exit(fn ->
      case GameRegistry.lookup(game_id) do
        {:ok, pid} -> if Process.alive?(pid), do: GenServer.stop(pid)
        :error -> :ok
      end
    end)
  end
end
