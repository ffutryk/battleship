defmodule BattleshipWeb.HomeLive do
  use BattleshipWeb, :live_view

  alias Battleship.Matchmaking.Queue

  @impl true
  def mount(_params, _session, socket) do
    player = %{
      id: System.unique_integer([:positive])
    }

    socket =
      socket
      |> assign(player: player, state: :idle)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-dvh flex flex-col items-center justify-center bg-ocean font-silkscreen px-4 gap-8">
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
    %{state: state, player: player} = socket.assigns

    new_state =
      case state do
        :idle -> start_matchmaking(player)
        :matchmaking -> cancel_matchmaking(player)
        _ -> state
      end

    {:noreply, assign(socket, state: new_state)}
  end

  @impl true
  def handle_info({:match_found, game_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
  end

  @impl true
  def handle_info({:error, reason}, socket) do
    {:noreply,
     socket
     |> assign(status: :idle)
     |> put_flash(:error, "Error al buscar partida: #{reason}")}
  end

  defp start_matchmaking(player) do
    Phoenix.PubSub.subscribe(Battleship.PubSub, "matchmaking:#{player.id}")
    Queue.join_queue(player, self())
    :matchmaking
  end

  defp cancel_matchmaking(player) do
    Queue.leave_queue(player)
    Phoenix.PubSub.unsubscribe(Battleship.PubSub, "matchmaking:#{player.id}")
    :idle
  end
end
