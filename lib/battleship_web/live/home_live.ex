defmodule BattleshipWeb.HomeLive do
  use BattleshipWeb, :live_view

  alias Battleship.Matchmaking.Queue

  @impl true
  def mount(_params, session, socket) do
    player_token = session["player_token"]

    {:ok,
     socket
     |> assign(state: :idle)
     |> assign(player_id: player_token)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="h-full flex flex-col items-center justify-center px-4 gap-8">
      <div class="inline-flex justify-center items-start text-[clamp(3rem,14vw,8rem)]">
        <h1 class="text-hull tracking-[-0.2em]  stroke-text">
          BATTLESHIP
        </h1>
        <span class="ml-[0.05em] text-[0.5em] tracking-[-0.1em] leading-none">TM</span>
      </div>
      <.button class="btn-pixel" phx-click="play-guest">
        {if @state == :matchmaking, do: "Matchmaking", else: "Play as Guest"}
        <span :if={@state == :matchmaking} class="animate-dots"></span>
      </.button>
    </main>
    """
  end

  @impl true
  def handle_event("play-guest", _payload, socket) do
    %{state: state, player_id: player_id} = socket.assigns

    new_state =
      case state do
        :idle -> start_matchmaking(player_id)
        :matchmaking -> cancel_matchmaking(player_id)
        _ -> state
      end

    {:noreply, assign(socket, state: new_state, player_id: player_id)}
  end

  @impl true
  def handle_info({:match_found, game_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end

  @impl true
  def handle_info({:error, reason}, socket) do
    {:noreply,
     socket
     |> assign(state: :idle)
     |> put_flash(:error, "An error has ocurred during matchmaking: #{reason}")}
  end

  defp start_matchmaking(player_id) do
    Phoenix.PubSub.subscribe(Battleship.PubSub, "matchmaking:#{player_id}")
    Queue.join_queue(player_id, self())
    :matchmaking
  end

  defp cancel_matchmaking(player_id) do
    Queue.leave_queue(player_id)
    Phoenix.PubSub.unsubscribe(Battleship.PubSub, "matchmaking:#{player_id}")
    :idle
  end
end
