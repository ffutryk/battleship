defmodule Battleship.Game.Core.Board do
  @size 9
  @fleet [2, 2, 2, 2, 2]

  defstruct ships: [], shots: MapSet.new(), available_ships: @fleet

  alias Battleship.Game.Core.Ship

  def place_ship(%__MODULE__{available_ships: []}, _coords) do
    {:error, :max_ships_reached}
  end

  def place_ship(board, coords) do
    ship = %Ship{coordinates: MapSet.new(coords)}
    ship_length = length(coords)

    with :ok <- validate_not_empty(coords),
         :ok <- validate_bounds(coords),
         {:ok, remaining_ships} <- validate_and_pop_ship(board.available_ships, ship_length),
         :ok <- validate_straight_line(coords),
         :ok <- validate_no_overlap(board, ship) do
      updated_board = %{
        board
        | ships: [ship | board.ships],
          available_ships: remaining_ships
      }

      {:ok, updated_board}
    end
  end

  def all_sunken?(%__MODULE__{ships: ships, shots: shots}) do
    Enum.all?(ships, &Ship.sunk?(&1, shots))
  end

  def ready?(%__MODULE__{available_ships: []}), do: true
  def ready?(%__MODULE__{}), do: false

  defp validate_not_empty(coords) do
    if coords == [], do: {:error, :empty_ship}, else: :ok
  end

  defp validate_bounds(coords) do
    if Enum.all?(coords, &within_bounds?/1), do: :ok, else: {:error, :out_of_bounds}
  end

  defp validate_no_overlap(board, ship) do
    if overlaps?(board, ship), do: {:error, :overlapping}, else: :ok
  end

  defp validate_and_pop_ship(available_ships, ship_length) do
    if ship_length in available_ships do
      {:ok, List.delete(available_ships, ship_length)}
    else
      {:error, :invalid_or_unneeded_ship_size}
    end
  end

  defp validate_straight_line(coords) do
    case Enum.sort(coords) do
      [{r1, c1}, {r2, c2}] when r1 == r2 and c2 == c1 + 1 -> :ok
      [{r1, c1}, {r2, c2}] when c1 == c2 and r2 == r1 + 1 -> :ok
      _ -> {:error, :invalid_ship_shape}
    end
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
