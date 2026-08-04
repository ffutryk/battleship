defmodule Battleship.Game.ServerTest do
  use ExUnit.Case, async: true

  alias Battleship.Game.Server
  alias Battleship.Game.Registry, as: GameRegistry

  @fleet_coords [
    [{0, 0}, {0, 1}, {0, 2}, {0, 3}, {0, 4}],
    [{1, 0}, {1, 1}, {1, 2}, {1, 3}],
    [{2, 0}, {2, 1}, {2, 2}],
    [{3, 0}, {3, 1}],
    [{4, 0}]
  ]

  setup do
    game_id = "game-" <> Integer.to_string(System.unique_integer([:positive]))
    p1 = "p1"
    p2 = "p2"

    start_supervised!({Server, {game_id, [p1, p2]}})
    Phoenix.PubSub.subscribe(Battleship.PubSub, "game:#{game_id}")

    %{game_id: game_id, p1: p1, p2: p2}
  end

  describe "view/2" do
    test "returns the state for a known player before anyone connects", %{
      game_id: game_id,
      p1: p1
    } do
      assert {:ok, view} = Server.view(game_id, p1)
      assert view.phase == :waiting_opponent
    end

    test "returns an error for a player that isn't part of the game", %{game_id: game_id} do
      assert Server.view(game_id, "stranger") == {:error, :not_allowed}
    end

    test "returns an error when the game doesn't exist" do
      missing_id = "missing-" <> Integer.to_string(System.unique_integer([:positive]))

      assert Server.view(missing_id, "p1") == {:error, :game_not_found}
    end
  end

  describe "connect/3" do
    test "moves to the placement phase once both players connect", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      assert :ok = Server.connect(game_id, p1, self())
      assert {:ok, %{phase: :waiting_opponent}} = Server.view(game_id, p1)

      assert :ok = Server.connect(game_id, p2, self())

      assert_receive {:phase_changed, :placement, _remaining_ms}
      assert {:ok, %{phase: :placement}} = Server.view(game_id, p1)
    end

    test "returns an error for a player that isn't part of the game", %{game_id: game_id} do
      assert Server.connect(game_id, "stranger", self()) == {:error, :unknown_player}
    end
  end

  describe "place_ship/3" do
    test "places a ship during the placement phase", %{game_id: game_id, p1: p1, p2: p2} do
      connect_both(game_id, p1, p2)

      assert {:ok, board} = Server.place_ship(game_id, p1, [{0, 0}, {0, 1}])
      assert board.available_ships == [1, 3, 4, 5]
    end

    test "rejects placement outside the placement phase", %{game_id: game_id, p1: p1} do
      assert Server.place_ship(game_id, p1, [{0, 0}, {0, 1}]) ==
               {:error, :not_placement_phase}
    end

    test "propagates board validation errors", %{game_id: game_id, p1: p1, p2: p2} do
      connect_both(game_id, p1, p2)

      assert Server.place_ship(game_id, p1, [{0, 0}, {1, 1}]) ==
               {:error, :invalid_ship_shape}
    end
  end

  describe "confirm_placement/2" do
    test "rejects confirmation while the fleet is incomplete", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      connect_both(game_id, p1, p2)

      assert Server.confirm_placement(game_id, p1) == {:error, :incomplete_placement}
    end

    test "rejects confirmation outside the placement phase", %{game_id: game_id, p1: p1} do
      assert Server.confirm_placement(game_id, p1) == {:error, :not_placement_phase}
    end

    test "waits for both players before moving to battle", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      connect_both(game_id, p1, p2)
      place_full_fleet(game_id, p1)
      place_full_fleet(game_id, p2)

      assert :ok = Server.confirm_placement(game_id, p1)
      assert {:ok, %{phase: :placement}} = Server.view(game_id, p1)

      assert :ok = Server.confirm_placement(game_id, p2)
      assert_receive {:phase_changed, :battle}
      assert {:ok, %{phase: :battle}} = Server.view(game_id, p1)
    end
  end

  describe "shoot_at/3" do
    test "rejects shots outside the battle phase", %{game_id: game_id, p1: p1, p2: p2} do
      connect_both(game_id, p1, p2)

      assert Server.shoot_at(game_id, p1, {0, 0}) == {:error, :not_battle_phase}
    end

    test "rejects a shot from the player who isn't on turn", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      {shooter, waiter} = setup_battle_phase(game_id, p1, p2)
      refute shooter == waiter

      assert Server.shoot_at(game_id, waiter, {0, 0}) == {:error, :not_allowed}
    end

    test "registers a hit and passes the turn to the opponent", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      {shooter, _waiter} = setup_battle_phase(game_id, p1, p2)

      assert Server.shoot_at(game_id, shooter, {0, 0}) == :hit
      assert_receive :shot

      assert {:ok, %{is_turn?: false}} = Server.view(game_id, shooter)
    end

    test "registers a miss on an empty cell", %{game_id: game_id, p1: p1, p2: p2} do
      {shooter, _waiter} = setup_battle_phase(game_id, p1, p2)

      assert Server.shoot_at(game_id, shooter, {9, 9}) == :miss
    end

    test "rejects an out-of-bounds shot", %{game_id: game_id, p1: p1, p2: p2} do
      {shooter, _waiter} = setup_battle_phase(game_id, p1, p2)

      assert Server.shoot_at(game_id, shooter, {20, 20}) == {:error, :out_of_bounds}
    end

    test "declares the shooter as winner once the opponent's fleet is fully sunk", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      {shooter, responder} = setup_battle_phase(game_id, p1, p2)

      safe_coords = for row <- 5..9, col <- 0..9, do: {row, col}
      all_ship_coords = List.flatten(@fleet_coords)
      {initial_coords, [last_coord]} = Enum.split(all_ship_coords, length(all_ship_coords) - 1)

      final_safe_coords =
        Enum.reduce(initial_coords, safe_coords, fn coord, safe_coords ->
          safe_coords = ensure_turn(game_id, shooter, responder, safe_coords)
          assert Server.shoot_at(game_id, shooter, coord) in [:hit, :sunk]
          safe_coords
        end)

      _final_safe_coords = ensure_turn(game_id, shooter, responder, final_safe_coords)
      assert Server.shoot_at(game_id, shooter, last_coord) == :sunk

      assert_receive {:phase_changed, :game_over, ^shooter}
      assert {:ok, %{phase: :game_over, winner_id: ^shooter}} = Server.view(game_id, shooter)
    end
  end

  describe "placement timeout" do
    test "moves to battle once the placement timer fires, auto-filling boards", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      connect_both(game_id, p1, p2)

      {:ok, server_pid} = GameRegistry.lookup(game_id)
      send(server_pid, :placement_timeout)

      assert_receive {:phase_changed, :battle}
      assert {:ok, %{phase: :battle, player_board: board}} = Server.view(game_id, p1)
      assert board.available_ships == []
      assert length(board.ships) == 5
    end

    test "is ignored outside the placement phase", %{game_id: game_id, p1: p1, p2: p2} do
      {shooter, _waiter} = setup_battle_phase(game_id, p1, p2)

      {:ok, server_pid} = GameRegistry.lookup(game_id)
      send(server_pid, :placement_timeout)

      assert {:ok, %{phase: :battle}} = Server.view(game_id, shooter)
    end
  end

  describe "game over shutdown" do
    test "stops the game process after a :game_over_shutdown message", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      {:ok, server_pid} = GameRegistry.lookup(game_id)
      connect_both(game_id, p1, p2)

      ref = Process.monitor(server_pid)
      send(server_pid, :game_over_shutdown)

      assert_receive :game_closed, 500
      assert_receive {:DOWN, ^ref, :process, ^server_pid, :normal}, 500
    end
  end

  describe "disconnection" do
    test "keeps the game alive if only one player disconnects", %{
      game_id: game_id,
      p1: p1,
      p2: p2
    } do
      dummy_pid = spawn(fn -> Process.sleep(:infinity) end)

      assert :ok = Server.connect(game_id, p1, dummy_pid)
      assert :ok = Server.connect(game_id, p2, self())
      assert_receive {:phase_changed, :placement, _remaining_ms}

      Process.exit(dummy_pid, :kill)

      assert {:ok, %{phase: :placement}} = Server.view(game_id, p2)
    end

    test "stops the game once every player disconnects", %{game_id: game_id, p1: p1, p2: p2} do
      dummy_pid_1 = spawn(fn -> Process.sleep(:infinity) end)
      dummy_pid_2 = spawn(fn -> Process.sleep(:infinity) end)

      assert :ok = Server.connect(game_id, p1, dummy_pid_1)
      assert :ok = Server.connect(game_id, p2, dummy_pid_2)
      assert_receive {:phase_changed, :placement, _remaining_ms}

      {:ok, server_pid} = GameRegistry.lookup(game_id)
      ref = Process.monitor(server_pid)

      Process.exit(dummy_pid_1, :kill)
      Process.exit(dummy_pid_2, :kill)

      assert_receive {:DOWN, ^ref, :process, ^server_pid, :normal}, 500
    end
  end

  defp connect_both(game_id, p1, p2) do
    assert :ok = Server.connect(game_id, p1, self())
    assert :ok = Server.connect(game_id, p2, self())
    assert_receive {:phase_changed, :placement, _remaining_ms}
  end

  defp place_full_fleet(game_id, player_id) do
    Enum.each(@fleet_coords, fn coords ->
      assert {:ok, _board} = Server.place_ship(game_id, player_id, coords)
    end)
  end

  defp setup_battle_phase(game_id, p1, p2) do
    connect_both(game_id, p1, p2)
    place_full_fleet(game_id, p1)
    place_full_fleet(game_id, p2)

    assert :ok = Server.confirm_placement(game_id, p1)
    assert :ok = Server.confirm_placement(game_id, p2)
    assert_receive {:phase_changed, :battle}

    {:ok, view} = Server.view(game_id, p1)
    if view.is_turn?, do: {p1, p2}, else: {p2, p1}
  end

  defp ensure_turn(game_id, player_id, other_id, safe_coords) do
    {:ok, view} = Server.view(game_id, player_id)

    if view.is_turn? do
      safe_coords
    else
      [coord | rest] = safe_coords
      Server.shoot_at(game_id, other_id, coord)
      ensure_turn(game_id, player_id, other_id, rest)
    end
  end
end
