defmodule Battleship.Game.Bot do
  use GenServer

  alias Battleship.Game.Server
  alias Battleship.Game.Core.Board

  @shot_delay 400..900
  @hover_delay 250..500

  def start_link({game_id, bot_id}) do
    GenServer.start_link(__MODULE__, {game_id, bot_id})
  end

  def gen_id, do: "bot_" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)

  @impl true
  def init({game_id, bot_id}) do
    Phoenix.PubSub.subscribe(Battleship.PubSub, "game:#{game_id}")
    :ok = Server.connect(game_id, bot_id, self())

    {:ok, %{game_id: game_id, bot_id: bot_id}}
  end

  @impl true
  def handle_info({:phase_changed, :placement, _}, state),
    do: place_random_ships(state)

  @impl true
  def handle_info({:phase_changed, :battle}, state),
    do: maybe_schedule_shot(state)

  @impl true
  def handle_info({:phase_changed, :game_over, _}, state),
    do: {:stop, :normal, state}

  @impl true
  def handle_info(:shot, state),
    do: maybe_schedule_shot(state)

  @impl true
  def handle_info(:fire, state) do
    fire(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(_, state),
    do: {:noreply, state}

  defp place_random_ships(%{game_id: game_id, bot_id: bot_id} = state) do
    %Board{}
    |> Board.fill_random()
    |> then(fn board ->
      Enum.each(board.ships, fn ship ->
        Server.place_ship(game_id, bot_id, ship.coordinates)
      end)
    end)

    Server.confirm_placement(game_id, bot_id)

    {:noreply, state}
  end

  defp maybe_schedule_shot(%{game_id: game_id, bot_id: bot_id} = state) do
    case Server.view(game_id, bot_id) do
      {:ok, %{phase: :battle, is_turn?: true}} ->
        Process.send_after(self(), :fire, Enum.random(@shot_delay))

      _ ->
        :ok
    end

    {:noreply, state}
  end

  defp fire(%{game_id: game_id, bot_id: bot_id} = state) do
    with {:ok, %{phase: :battle, is_turn?: true} = view} <- Server.view(game_id, bot_id),
         {:ok, candidates} <- shot_candidates(view.player_shots) do
      hover_path =
        candidates
        |> Enum.shuffle()
        |> Enum.take(Enum.random(2..10))

      emulate_hover_think(state, hover_path)

      Server.shoot_at(game_id, bot_id, List.last(hover_path))
    end
  end

  defp shot_candidates(already_shot) do
    candidates =
      for row <- 0..9,
          col <- 0..9,
          not Map.has_key?(already_shot, {row, col}) do
        {row, col}
      end

    case candidates do
      [] -> {:error, :no_targets_left}
      _ -> {:ok, candidates}
    end
  end

  defp emulate_hover_think(%{game_id: game_id, bot_id: bot_id}, candidates) do
    Enum.each(candidates, fn coord ->
      Phoenix.PubSub.broadcast_from(
        Battleship.PubSub,
        self(),
        "game:#{game_id}",
        {:opponent_hover, bot_id, coord}
      )

      Process.sleep(Enum.random(@hover_delay))
    end)
  end
end
