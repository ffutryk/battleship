defmodule Battleship.Game.StateTest do
  use ExUnit.Case, async: true

  alias Battleship.Game.State
  alias Battleship.Game.Core.Board

  describe "init/2" do
    test "builds an initial state with a board and player entry per player" do
      state = State.init("game-1", ["p1", "p2"])

      assert state.id == "game-1"
      assert state.phase == :waiting_opponent
      assert state.battle_turn == nil
      assert state.winner_id == nil
      assert Map.keys(state.boards) |> Enum.sort() == ["p1", "p2"]
      assert state.boards["p1"] == %Board{}

      assert state.players == %{
               "p1" => %{connected: false, ready: false},
               "p2" => %{connected: false, ready: false}
             }
    end

    test "accepts an optional timer ref" do
      state = State.init("game-1", ["p1", "p2"], :some_ref)

      assert state.timer_ref == :some_ref
    end
  end

  describe "next_phase/1" do
    test "moves from waiting_opponent to placement" do
      state = State.init("game-1", ["p1", "p2"])

      assert %State{phase: :placement} = State.next_phase(state)
    end

    test "moves from placement to battle and picks a battle_turn among players" do
      state =
        "game-1"
        |> State.init(["p1", "p2"])
        |> State.next_phase()
        |> State.next_phase()

      assert state.phase == :battle
      assert state.timer_ref == nil
      assert state.battle_turn in ["p1", "p2"]
    end

    test "moves from battle to game_over and crowns the current shooter as winner" do
      state =
        "game-1"
        |> State.init(["p1", "p2"])
        |> State.next_phase()
        |> State.next_phase()

      shooter = state.battle_turn

      final_state = State.next_phase(state)

      assert final_state.phase == :game_over
      assert final_state.winner_id == shooter
    end
  end

  describe "mark_connected/3 and mark_disconnected/2" do
    test "marks a known player as connected with its pid" do
      state = State.init("game-1", ["p1", "p2"])

      state = State.mark_connected(state, "p1", self())

      assert state.players["p1"].connected == true
      assert state.players["p1"].pid == self()
    end

    test "marks a known player as disconnected and clears its pid" do
      state =
        "game-1"
        |> State.init(["p1", "p2"])
        |> State.mark_connected("p1", self())
        |> State.mark_disconnected("p1")

      assert state.players["p1"].connected == false
      assert state.players["p1"].pid == nil
    end

    test "returns an error for an unknown player" do
      state = State.init("game-1", ["p1", "p2"])

      assert State.mark_connected(state, "unknown", self()) == {:error, :unknown_player}
      assert State.mark_disconnected(state, "unknown") == {:error, :unknown_player}
    end
  end

  describe "all_connected?/1 and all_disconnected?/1" do
    test "all_connected? is false until every player has connected" do
      state = State.init("game-1", ["p1", "p2"])

      refute State.all_connected?(state)

      state = State.mark_connected(state, "p1", self())
      refute State.all_connected?(state)

      state = State.mark_connected(state, "p2", self())
      assert State.all_connected?(state)
    end

    test "all_disconnected? is true when nobody is connected" do
      state = State.init("game-1", ["p1", "p2"])

      assert State.all_disconnected?(state)

      state = State.mark_connected(state, "p1", self())
      refute State.all_disconnected?(state)
    end
  end

  describe "mark_ready/2" do
    test "marks a player ready during the placement phase" do
      state =
        "game-1"
        |> State.init(["p1", "p2"])
        |> State.next_phase()

      state = State.mark_ready(state, "p1")

      assert state.players["p1"].ready == true
    end

    test "returns an error outside the placement phase" do
      state = State.init("game-1", ["p1", "p2"])

      assert State.mark_ready(state, "p1") == {:error, :not_placement_phase}
    end
  end

  describe "all_ready?/1" do
    test "is true only once every player is ready" do
      state =
        "game-1"
        |> State.init(["p1", "p2"])
        |> State.next_phase()

      refute State.all_ready?(state)

      state = State.mark_ready(state, "p1")
      refute State.all_ready?(state)

      state = State.mark_ready(state, "p2")
      assert State.all_ready?(state)
    end
  end

  describe "opponent_board/2" do
    test "returns the board belonging to the other player" do
      state = State.init("game-1", ["p1", "p2"])
      {:ok, ship_board} = Board.place_ship(%Board{}, [{0, 0}])
      state = %{state | boards: Map.put(state.boards, "p2", ship_board)}

      assert State.opponent_board(state, "p1") == ship_board
    end
  end

  describe "opponent_id/2" do
    test "returns the id of the other player" do
      state = State.init("game-1", ["p1", "p2"])

      assert State.opponent_id(state, "p1") == "p2"
      assert State.opponent_id(state, "p2") == "p1"
    end
  end

  describe "next_turn/1" do
    test "switches battle_turn to the other player" do
      state =
        "game-1"
        |> State.init(["p1", "p2"])
        |> State.next_phase()
        |> State.next_phase()

      current = state.battle_turn
      next_state = State.next_turn(state)

      refute next_state.battle_turn == current
      assert next_state.battle_turn in ["p1", "p2"]
    end
  end
end
