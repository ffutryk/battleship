defmodule Battleship.Game.Registry do
  def child_spec(_opts), do: Registry.child_spec(keys: :unique, name: __MODULE__)

  def via_tuple(game_id), do: {:via, Registry, {__MODULE__, game_id}}

  def lookup(game_id) do
    case Registry.lookup(__MODULE__, game_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
end
