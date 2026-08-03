defmodule BattleshipWeb.Game.PegSprites do
  use BattleshipWeb, :verified_routes

  @peg_files %{
    :hit => "hit.png",
    :miss => "miss.png",
    :sunk => "sunk.png",
    :own_hit => "own_hit.png",
    :own_miss => "own_miss.png",
    :own_sunk => "own_hit.png"
  }

  def sprite_for(status, own?) when status in [:hit, :miss, :sunk] and is_boolean(own?) do
    key = if own?, do: own_key(status), else: status
    path(@peg_files[key])
  end

  defp own_key(:hit), do: :own_hit
  defp own_key(:miss), do: :own_miss
  defp own_key(:sunk), do: :own_sunk

  defp path(filename), do: ~p"/images/pegs/#{filename}"
end
