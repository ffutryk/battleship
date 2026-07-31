defmodule Battleship.Game.Coordinator do
  alias Battleship.Game.Supervisor

  def create_game(player_ids) do
    game_id = System.unique_integer([:positive])

    case Supervisor.start_game(game_id, player_ids) do
      {:ok, _pid} ->
        notify_players(player_ids, {:match_found, game_id})
        {:ok, game_id}

      {:error, reason} ->
        notify_players(player_ids, {:error, reason})
        {:error, reason}
    end
  end

  defp notify_players(player_ids, message) do
    Enum.each(player_ids, fn id ->
      broadcast_matchmaking(id, message)
    end)
  end

  defp broadcast_matchmaking(id, message) do
    Phoenix.PubSub.broadcast(
      Battleship.PubSub,
      "matchmaking:#{id}",
      message
    )
  end
end
