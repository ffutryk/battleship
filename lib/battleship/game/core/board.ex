defmodule Battleship.Game.Core.Board do
  defstruct ships: [], shots: MapSet.new()

  alias Battleship.Game.Core.Ship

  @size 9

  def place_ship(board, coords) do
    ship = %Ship{coordinates: MapSet.new(coords)}

    with :ok <- validate_not_empty(coords),
         :ok <- validate_bounds(coords),
         :ok <- validate_no_overlap(board, ship) do
      {:ok, %{board | ships: [ship | board.ships]}}
    end
  end

  defp validate_not_empty(coords) do
    if coords == [], do: {:error, :empty_ship}, else: :ok
  end

  defp validate_bounds(coords) do
    if Enum.all?(coords, &within_bounds?/1), do: :ok, else: {:error, :out_of_bounds}
  end

  defp validate_no_overlap(board, ship) do
    if overlaps?(board, ship), do: {:error, :overlapping}, else: :ok
  end

  def all_sunken?(%__MODULE__{ships: ships, shots: shots}) do
    Enum.all?(ships, &Ship.sunk?(&1, shots))
  end

  defp within_bounds?({row, col}) do
    within_bounds?(row) and within_bounds?(col)
  end

  defp within_bounds?(n) when is_integer(n), do: n in 0..@size

  defp overlaps?(%__MODULE__{ships: ships}, %Ship{coordinates: coords}) do
    Enum.any?(ships, fn ship ->
      not MapSet.disjoint?(ship.coordinates, coords)
    end)
  end
end
