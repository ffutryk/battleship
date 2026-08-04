defmodule Battleship.Game.MatchSupervisor do
  use Supervisor

  alias Battleship.Game.{Server, Bot}

  def start_link(args), do: Supervisor.start_link(__MODULE__, args)

  @impl true
  def init({game_id, player_ids, bot_id}) do
    all_players = if bot_id, do: player_ids ++ [bot_id], else: player_ids

    children =
      [
        Supervisor.child_spec(
          {Server, {game_id, all_players}},
          restart: :transient,
          significant: true
        )
      ]
      |> maybe_supervise_bot(game_id, bot_id)

    Supervisor.init(children, strategy: :rest_for_one, auto_shutdown: :any_significant)
  end

  defp maybe_supervise_bot(child_specs, _game_id, nil), do: child_specs

  defp maybe_supervise_bot(child_specs, game_id, bot_id),
    do: child_specs ++ [Supervisor.child_spec({Bot, {game_id, bot_id}}, restart: :transient)]
end
