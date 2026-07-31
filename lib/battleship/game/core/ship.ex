defmodule Battleship.Game.Core.Ship do
  defstruct coordinates: MapSet.new()

  @valid_lengths [2]

  def valid_lengths, do: @valid_lengths

  def valid_length?(length) when is_integer(length) do
    length in @valid_lengths
  end

  def length(%__MODULE__{coordinates: coordinates}), do: MapSet.size(coordinates)

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
