defmodule BattleshipWeb.Game.ShipSprites do
  use BattleshipWeb, :verified_routes

  alias Battleship.Game.Core.Ship

  @sprite_files %{
    1 => ["submarine.png"],
    2 => ["frigate_bow.png", "frigate_stern.png"],
    3 => ["destroyer_bow.png", "destroyer_mid.png", "destroyer_stern.png"],
    4 => ["cruiser_bow.png", "cruiser_mid_1.png", "cruiser_mid_2.png", "cruiser_stern.png"],
    5 => [
      "battleship_bow.png",
      "battleship_mid_1.png",
      "battleship_mid_2.png",
      "battleship_mid_3.png",
      "battleship_stern.png"
    ]
  }

  def for_length(length) do
    if Ship.valid_length?(length) do
      @sprite_files
      |> Map.fetch!(length)
      |> stretch(length)
      |> Enum.map(&path/1)
    else
      raise "Unsupported ship length: #{length}"
    end
  end

  def fleet_cells(ships) do
    ships
    |> Enum.flat_map(&cell_sprites/1)
    |> Map.new(&{&1.coord, &1})
  end

  def cell_sprites(%Ship{coordinates: coordinates}) do
    ordered_coords = Enum.sort(MapSet.to_list(coordinates))
    ship_length = length(ordered_coords)
    sprites = for_length(ship_length)
    orientation = orientation_of(ordered_coords)

    ordered_coords
    |> Enum.zip(sprites)
    |> Enum.with_index()
    |> Enum.map(fn {{coord, src}, index} ->
      %{coord: coord, src: src, style: transform_style(index, ship_length, orientation)}
    end)
  end

  defp orientation_of([_single]), do: :horizontal

  defp orientation_of([{r1, _c1}, {r2, _c2} | _]) do
    if r1 == r2, do: :horizontal, else: :vertical
  end

  defp transform_style(_index, 1, _orientation), do: nil

  defp transform_style(index, length, orientation) do
    center =
      if rem(length, 2) == 0 do
        length / 2 - 0.5
      else
        div(length, 2) * 1.0
      end

    distance = abs(index - center)
    base = if rem(length, 2) == 0, do: 2, else: 0
    sign = if index < center, do: 1, else: -1
    offset = round((base + distance * 4) * sign)

    {x, y} = if orientation == :horizontal, do: {offset, 0}, else: {0, offset}
    rotate = if orientation == :vertical, do: " rotate(90deg)", else: ""

    "transform: translate(#{x}px, #{y}px)#{rotate};"
  end

  defp path(filename), do: ~p"/images/ships/#{filename}"

  defp stretch(sprites, 1), do: [List.first(sprites)]

  defp stretch(sprites, length) when length >= 2 do
    bow = List.first(sprites)
    stern = List.last(sprites)
    mids_needed = length - 2

    mids =
      if mids_needed <= 0 do
        []
      else
        mid_pool =
          case Enum.slice(sprites, 1..-2//1) do
            [] -> [bow]
            pool -> pool
          end

        mid_pool |> Stream.cycle() |> Enum.take(mids_needed)
      end

    [bow] ++ mids ++ [stern]
  end
end
