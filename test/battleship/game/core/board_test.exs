defmodule Battleship.Game.Core.BoardTest do
  use ExUnit.Case, async: true

  alias Battleship.Game.Core.Board

  describe "place_ship/2" do
    test "places a valid horizontal ship on an empty board" do
      assert {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}, {0, 2}])

      assert [ship] = board.ships
      assert ship.coordinates == MapSet.new([{0, 0}, {0, 1}, {0, 2}])
      assert board.available_ships == [1, 2, 4, 5]
    end

    test "places a valid vertical ship on an empty board" do
      assert {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {1, 0}])

      assert board.available_ships == [1, 3, 4, 5]
    end

    test "places every ship of the fleet without overlapping" do
      coords_by_length = [
        [{0, 0}, {0, 1}, {0, 2}, {0, 3}, {0, 4}],
        [{1, 0}, {1, 1}, {1, 2}, {1, 3}],
        [{2, 0}, {2, 1}, {2, 2}],
        [{3, 0}, {3, 1}],
        [{4, 0}]
      ]

      board =
        Enum.reduce(coords_by_length, %Board{}, fn coords, board ->
          assert {:ok, updated_board} = Board.place_ship(board, coords)
          updated_board
        end)

      assert board.available_ships == []
      assert Board.ready?(board)
    end

    test "rejects a ship once the fleet is complete" do
      board = fully_placed_board()

      assert Board.place_ship(board, [{9, 9}]) == {:error, :max_ships_reached}
    end

    test "rejects empty coordinates" do
      assert Board.place_ship(%Board{}, []) == {:error, :empty_ship}
    end

    test "rejects coordinates outside the board bounds" do
      assert Board.place_ship(%Board{}, [{9, 9}, {9, 10}]) == {:error, :out_of_bounds}
      assert Board.place_ship(%Board{}, [{-1, 0}]) == {:error, :out_of_bounds}
    end

    test "rejects a ship length that isn't in the remaining fleet" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}])

      assert Board.place_ship(board, [{5, 0}, {5, 1}]) ==
               {:error, :invalid_or_unneeded_ship_size}
    end

    test "rejects coordinates that don't form a straight line" do
      assert Board.place_ship(%Board{}, [{0, 0}, {1, 1}]) == {:error, :invalid_ship_shape}
    end

    test "rejects coordinates that are not contiguous" do
      assert Board.place_ship(%Board{}, [{0, 0}, {0, 2}, {0, 4}]) ==
               {:error, :invalid_ship_shape}
    end

    test "rejects a ship overlapping with an existing one" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}, {0, 2}])

      assert Board.place_ship(board, [{0, 2}, {1, 2}]) == {:error, :overlapping}
    end
  end

  describe "ready?/1" do
    test "returns false while ships remain to be placed" do
      refute Board.ready?(%Board{})
    end

    test "returns true once the whole fleet has been placed" do
      assert Board.ready?(fully_placed_board())
    end
  end

  describe "fill_random/1" do
    test "fills all remaining ships and leaves the board ready" do
      board = Board.fill_random(%Board{})

      assert board.available_ships == []
      assert Board.ready?(board)
      assert length(board.ships) == 5
    end

    test "does nothing when the board is already fully placed" do
      board = fully_placed_board()

      assert Board.fill_random(board) == board
    end

    test "only fills the ships that are still missing" do
      {:ok, board} = Board.place_ship(%Board{}, [{9, 9}])

      filled_board = Board.fill_random(board)

      assert filled_board.available_ships == []
      assert length(filled_board.ships) == 5
      assert Enum.any?(filled_board.ships, &(&1.coordinates == MapSet.new([{9, 9}])))
    end
  end

  describe "all_sunken?/1" do
    test "returns true when there are no ships" do
      assert Board.all_sunken?(%Board{})
    end

    test "returns false when at least one ship is afloat" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}])

      refute Board.all_sunken?(board)
    end

    test "returns true once every ship has been sunk" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}])

      board = %{board | shots: MapSet.new([{0, 0}, {0, 1}])}

      assert Board.all_sunken?(board)
    end
  end

  describe "receive_shot/2" do
    test "returns :miss when the shot doesn't hit any ship" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}])

      assert {new_board, :miss} = Board.receive_shot(board, {5, 5})
      assert MapSet.member?(new_board.shots, {5, 5})
    end

    test "returns :hit when the shot hits a ship without sinking it" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}])

      assert {new_board, :hit} = Board.receive_shot(board, {0, 0})
      assert MapSet.member?(new_board.shots, {0, 0})
    end

    test "returns :sunk when the shot sinks the last afloat part of a ship" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}])

      assert {_new_board, :sunk} = Board.receive_shot(board, {0, 0})
    end

    test "returns an error for out-of-bounds coordinates" do
      assert Board.receive_shot(%Board{}, {10, 10}) == {:error, :out_of_bounds}
    end
  end

  describe "shot_results/1" do
    test "maps each shot coordinate to its result" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}])
      {board, _} = Board.receive_shot(board, {0, 0})
      {board, _} = Board.receive_shot(board, {0, 1})
      {board, _} = Board.receive_shot(board, {5, 5})

      assert Board.shot_results(board) == %{
               {0, 0} => :sunk,
               {0, 1} => :sunk,
               {5, 5} => :miss
             }
    end

    test "reports :hit for a partially damaged ship" do
      {:ok, board} = Board.place_ship(%Board{}, [{0, 0}, {0, 1}, {0, 2}])
      {board, _} = Board.receive_shot(board, {0, 0})

      assert Board.shot_results(board) == %{{0, 0} => :hit}
    end
  end

  defp fully_placed_board do
    coords_by_length = [
      [{0, 0}, {0, 1}, {0, 2}, {0, 3}, {0, 4}],
      [{1, 0}, {1, 1}, {1, 2}, {1, 3}],
      [{2, 0}, {2, 1}, {2, 2}],
      [{3, 0}, {3, 1}],
      [{4, 0}]
    ]

    Enum.reduce(coords_by_length, %Board{}, fn coords, board ->
      {:ok, updated_board} = Board.place_ship(board, coords)
      updated_board
    end)
  end
end
