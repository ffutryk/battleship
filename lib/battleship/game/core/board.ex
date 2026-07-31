defmodule Battleship.Game.Core.Board do
  @size 9
  @fleet [1, 2, 3, 4, 5]

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

  def fill_random(%__MODULE__{available_ships: []} = board), do: board

  def fill_random(%__MODULE__{available_ships: [length | _]} = board) do
    case random_candidate(board, length) do
      {:ok, coords} ->
        {:ok, updated_board} = place_ship(board, coords)
        fill_random(updated_board)

      :error ->
        {:error, :no_space_left}
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

  defp validate_and_pop_ship(available_ships, ship_length) do
    if ship_length in available_ships do
      {:ok, List.delete(available_ships, ship_length)}
    else
      {:error, :invalid_or_unneeded_ship_size}
    end
  end

  defp validate_straight_line(coords) when length(coords) in 1..5 do
    pairs =
      coords
      |> Enum.sort()
      |> Enum.chunk_every(2, 1, :discard)

    is_horizontal = Enum.all?(pairs, fn [{r1, c1}, {r2, c2}] -> r1 == r2 and c2 == c1 + 1 end)
    is_vertical = Enum.all?(pairs, fn [{r1, c1}, {r2, c2}] -> c1 == c2 and r2 == r1 + 1 end)

    if is_horizontal or is_vertical do
      :ok
    else
      {:error, :invalid_ship_shape}
    end
  end

  defp validate_straight_line(_), do: {:error, :invalid_ship_shape}

  defp within_bounds?({row, col}) do
    within_bounds?(row) and within_bounds?(col)
  end

  defp within_bounds?(n) when is_integer(n), do: n in 0..@size

  defp overlaps?(%__MODULE__{ships: ships}, %Ship{coordinates: coords}) do
    Enum.any?(ships, fn ship ->
      not MapSet.disjoint?(ship.coordinates, coords)
    end)
  end

  defp random_candidate(board, length) do
    candidates =
      for row <- 0..@size,
          col <- 0..@size,
          orientation <- [:horizontal, :vertical],
          coords = ship_coords(row, col, length, orientation),
          Enum.all?(coords, &within_bounds?/1),
          not overlaps?(board, %Ship{coordinates: MapSet.new(coords)}) do
        coords
      end

    case candidates do
      [] -> :error
      list -> {:ok, Enum.random(list)}
    end
  end

  defp ship_coords(row, col, length, :horizontal) do
    Enum.map(0..(length - 1), fn c -> {row, col + c} end)
  end

  defp ship_coords(row, col, length, :vertical) do
    Enum.map(0..(length - 1), fn r -> {row + r, col} end)
  end
end
