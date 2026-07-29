defmodule Battleship.Game.Coordinator do
  alias Battleship.Game.Supervisor

  def create_game(players) do
    game_id = System.unique_integer([:positive])

    case Supervisor.start_game(game_id, players) do
      {:ok, _pid} ->
        notify_players(players, {:match_found, game_id})
        {:ok, game_id}

      {:error, reason} ->
        notify_players(players, {:error, reason})
        {:error, reason}
    end
  end

  defp notify_players(players, message) do
    Enum.each(players, fn player ->
      broadcast_matchmaking(player, message)
    end)
  end

  defp broadcast_matchmaking(player, message) do
    Phoenix.PubSub.broadcast(
      Battleship.PubSub,
      "matchmaking:#{player.id}",
      message
    )
  end
end
