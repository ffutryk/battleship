defmodule Battleship.Game.Core.Ship do
  defstruct coordinates: MapSet.new()

  def sunk?(%__MODULE__{coordinates: coordinates}, shots) do
    MapSet.subset?(coordinates, shots)
  end

  def hit?(%__MODULE__{coordinates: coordinates}, shots) do
    not MapSet.disjoint?(coordinates, shots)
  end

  def afloat?(%__MODULE__{} = ship, shots) do
    not sunk?(ship, shots)
  end
end
