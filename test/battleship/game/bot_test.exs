defmodule Battleship.Game.BotTest do
  use ExUnit.Case, async: true

  alias Battleship.Game.{Bot, Server}

  @fleet_coords [
    [{0, 0}, {0, 1}, {0, 2}, {0, 3}, {0, 4}],
    [{1, 0}, {1, 1}, {1, 2}, {1, 3}],
    [{2, 0}, {2, 1}, {2, 2}],
    [{3, 0}, {3, 1}],
    [{4, 0}]
  ]

  describe "gen_id/0" do
    test "generates unique ids prefixed with bot_" do
      id1 = Bot.gen_id()
      id2 = Bot.gen_id()

      assert String.starts_with?(id1, "bot_")
      assert String.starts_with?(id2, "bot_")
      assert id1 != id2
    end
  end

  describe "connecting and placement" do
    test "connects on init and only progresses once the human also connects" do
      {game_id, human, _bot_id, _bot_pid} = start_game_with_bot()

      assert {:ok, %{phase: :waiting_opponent}} = Server.view(game_id, human)

      assert :ok = Server.connect(game_id, human, self())
      assert_receive {:phase_changed, :placement, _remaining_ms}, 1000
    end

    test "automatically places a full fleet and confirms placement" do
      {game_id, human, bot_id, _bot_pid} = start_game_with_bot()

      assert :ok = Server.connect(game_id, human, self())
      assert_receive {:phase_changed, :placement, _remaining_ms}, 1000

      place_full_fleet(game_id, human)
      assert :ok = Server.confirm_placement(game_id, human)

      assert_receive {:phase_changed, :battle}, 1000

      assert {:ok, %{phase: :battle, player_board: board}} = Server.view(game_id, bot_id)
      assert board.available_ships == []
      assert length(board.ships) == 5
    end
  end

  describe "battle behaviour" do
    test "fires a shot automatically once it becomes its turn" do
      {game_id, human, _bot_id, _bot_pid} = start_game_with_bot()

      assert :ok = Server.connect(game_id, human, self())
      assert_receive {:phase_changed, :placement, _remaining_ms}, 1000

      place_full_fleet(game_id, human)
      assert :ok = Server.confirm_placement(game_id, human)
      assert_receive {:phase_changed, :battle}, 1000

      {:ok, %{is_turn?: human_turn?}} = Server.view(game_id, human)

      if human_turn? do
        assert Server.shoot_at(game_id, human, {9, 9}) in [:hit, :miss, :sunk]
        assert_receive :shot, 200
      end

      assert_receive :shot, 6_000

      assert {:ok, %{is_turn?: true}} = Server.view(game_id, human)
    end
  end

  describe "game over" do
    test "stops once the game_over phase is broadcast" do
      {game_id, _human, _bot_id, bot_pid} = start_game_with_bot()

      ref = Process.monitor(bot_pid)

      Phoenix.PubSub.broadcast(
        Battleship.PubSub,
        "game:#{game_id}",
        {:phase_changed, :game_over, "someone"}
      )

      assert_receive {:DOWN, ^ref, :process, ^bot_pid, :normal}
    end
  end

  describe "unrelated messages" do
    test "are ignored without crashing the bot" do
      {_game_id, _human, _bot_id, bot_pid} = start_game_with_bot()

      send(bot_pid, :some_unexpected_message)
      _ = :sys.get_state(bot_pid)

      assert Process.alive?(bot_pid)
    end
  end

  defp start_game_with_bot do
    game_id = "game-" <> Integer.to_string(System.unique_integer([:positive]))
    human = "human"
    bot_id = Bot.gen_id()

    start_supervised!({Server, {game_id, [human, bot_id]}})
    Phoenix.PubSub.subscribe(Battleship.PubSub, "game:#{game_id}")

    bot_pid = start_supervised!({Bot, {game_id, bot_id}})

    {game_id, human, bot_id, bot_pid}
  end

  defp place_full_fleet(game_id, player_id) do
    Enum.each(@fleet_coords, fn coords ->
      assert {:ok, _board} = Server.place_ship(game_id, player_id, coords)
    end)
  end
end
