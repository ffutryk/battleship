defmodule Battleship.Game.Coordinator do
  alias Battleship.Game.Supervisor

  def create_game(players) do
    game_id = System.unique_integer([:positive])

    case Supervisor.start_game(game_id, players) do
      {:ok, _pid} ->
        notify_players(players, :match_found, game_id)
        {:ok, game_id}

      {:error, reason} ->
        notify_players(players, :error, reason)
        {:error, reason}
    end
  end

  defp notify_players(players, :match_found, game_id) do
    Enum.each(players, fn player ->
      broadcast(player, {:match_found, game_id})
    end)
  end

  defp notify_players(players, :error, reason) do
    Enum.each(players, fn player ->
      broadcast(player, {:matchmaking_failed, reason})
    end)
  end

  defp broadcast(player, message) do
    Phoenix.PubSub.broadcast(
      Battleship.PubSub,
      "matchmaking:#{player.id}",
      message
    )
  end
end
