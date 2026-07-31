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
