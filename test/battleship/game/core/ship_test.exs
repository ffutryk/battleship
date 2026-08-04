defmodule Battleship.Game.Core.ShipTest do
  use ExUnit.Case, async: true

  alias Battleship.Game.Core.Ship

  describe "valid_lengths/0" do
    test "returns the range of valid ship lengths" do
      assert Ship.valid_lengths() == 1..5
    end
  end

  describe "valid_length?/1" do
    test "returns true for lengths within 1..5" do
      assert Ship.valid_length?(1)
      assert Ship.valid_length?(3)
      assert Ship.valid_length?(5)
    end

    test "returns false for lengths outside 1..5" do
      refute Ship.valid_length?(0)
      refute Ship.valid_length?(6)
      refute Ship.valid_length?(-1)
    end
  end

  describe "length/1" do
    test "returns the number of coordinates in the ship" do
      ship = %Ship{coordinates: MapSet.new([{0, 0}, {0, 1}, {0, 2}])}

      assert Ship.length(ship) == 3
    end

    test "returns zero for a ship with no coordinates" do
      assert Ship.length(%Ship{}) == 0
    end
  end

  describe "sunk?/2" do
    test "returns true when all coordinates have been shot" do
      ship = %Ship{coordinates: MapSet.new([{0, 0}, {0, 1}])}
      shots = MapSet.new([{0, 0}, {0, 1}, {5, 5}])

      assert Ship.sunk?(ship, shots)
    end

    test "returns false when some coordinates have not been shot" do
      ship = %Ship{coordinates: MapSet.new([{0, 0}, {0, 1}])}
      shots = MapSet.new([{0, 0}])

      refute Ship.sunk?(ship, shots)
    end

    test "returns true for a ship with no coordinates regardless of shots" do
      assert Ship.sunk?(%Ship{}, MapSet.new())
    end
  end

  describe "hit?/2" do
    test "returns true when at least one coordinate overlaps with the shots" do
      ship = %Ship{coordinates: MapSet.new([{0, 0}, {0, 1}])}
      shots = MapSet.new([{0, 1}, {9, 9}])

      assert Ship.hit?(ship, shots)
    end

    test "returns false when no coordinate overlaps with the shots" do
      ship = %Ship{coordinates: MapSet.new([{0, 0}, {0, 1}])}
      shots = MapSet.new([{5, 5}])

      refute Ship.hit?(ship, shots)
    end
  end

  describe "afloat?/2" do
    test "returns true when the ship is not sunk" do
      ship = %Ship{coordinates: MapSet.new([{0, 0}, {0, 1}])}
      shots = MapSet.new([{0, 0}])

      assert Ship.afloat?(ship, shots)
    end

    test "returns false when the ship is sunk" do
      ship = %Ship{coordinates: MapSet.new([{0, 0}, {0, 1}])}
      shots = MapSet.new([{0, 0}, {0, 1}])

      refute Ship.afloat?(ship, shots)
    end
  end
end
