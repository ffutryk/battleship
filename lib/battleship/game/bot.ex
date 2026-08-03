defmodule Battleship.Game.Bot do
  use GenServer

  alias Battleship.Game.Server

  def start_link({game_id, bot_id}) do
    GenServer.start_link(__MODULE__, {game_id, bot_id})
  end

  @impl true
  def init({game_id, bot_id}) do
    Phoenix.PubSub.subscribe(Battleship.PubSub, "game:#{game_id}")
    :ok = Server.connect(game_id, bot_id, self())

    {:ok, %{game_id: game_id, bot_id: bot_id}}
  end
end
