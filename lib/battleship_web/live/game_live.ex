defmodule BattleshipWeb.GameLive do
  use BattleshipWeb, :live_view

  alias Battleship.Game.Server
  import BattleshipWeb.GameComponents

  @impl true
  def mount(%{"id" => id}, session, socket) do
    player_token = session["player_token"]

    game_id =
      case Integer.parse(id) do
        {int, ""} -> int
        _ -> id
      end

    socket = assign(socket, game_id: game_id, player_id: player_token)

    handle_view(Server.view(game_id, player_token), socket)
  end

  @impl true
  def render(%{view: %{phase: :waiting_opponent}} = assigns), do: waiting_phase(assigns)
  def render(%{view: %{phase: :placement}} = assigns), do: placement_phase(assigns)
  def render(%{view: %{phase: :battle}} = assigns), do: battle_phase(assigns)

  defp waiting_phase(assigns) do
    ~H"""
    <main class="h-full flex items-center justify-center">
      Waiting for opponent<span class="animate-dots"></span>
    </main>
    """
  end

  defp placement_phase(%{view: %{player_board: board}} = assigns) do
    fleet =
      Enum.map(board.available_ships, fn length ->
        %{length: length, sprites: BattleshipWeb.Game.ShipSprites.for_length(length)}
      end)

    assigns =
      assigns
      |> assign(:fleet, fleet)

    ~H"""
    <main class="h-full flex flex-col items-center justify-center">
      <.timer id="timer-mobile" class="flex md:hidden mb-8" remaining_ms={@placement_remaining_ms} />
      <div
        id="panel"
        phx-hook="FleetPlacement"
        data-fleet={Jason.encode!(@fleet)}
        class="flex flex-col md:flex-row gap-8"
      >
        <div class="flex flex-col gap-2 items-center justify-center">
          <h2>Build your fleet</h2>
          <div class="flex flex-col lg:flex-row items-center lg:items-start gap-8">
            <.board id="board" />
          </div>
        </div>
        <div class="flex flex-col justify-center items-center gap-8">
          <.timer id="timer-desktop" class="hidden md:flex" remaining_ms={@placement_remaining_ms} />
          <div class="flex gap-4">
            <.button id="confirm-btn" class="btn-pixel w-fit px-8" disabled>Confirm</.button>
            <.button id="rotate-btn" class="btn-pixel-icon">
              <.rotate_icon />
            </.button>
          </div>
          <p class="text-center"><span id="remaining-count">5</span> remaining</p>
        </div>
      </div>
    </main>
    """
  end

  defp battle_phase(assigns) do
    ~H"""
    <main class="h-full flex flex-col items-center justify-center">
      Battle
    </main>
    """
  end

  @impl true
  def handle_info({:phase_changed, :placement, remaining_ms}, socket) do
    {:noreply,
     socket
     |> update(:view, &%{&1 | phase: :placement})
     |> assign(:placement_remaining_ms, remaining_ms)}
  end

  @impl true
  def handle_info({:phase_changed, new_phase}, socket) do
    {:noreply, update(socket, :view, &%{&1 | phase: new_phase})}
  end

  @impl true
  def handle_event("confirm_placement", %{"ships" => ships}, socket) do
    player_id = socket.assigns.player_id
    game_id = socket.assigns.game_id

    Enum.each(ships, fn ship_coords ->
      coords = Enum.map(ship_coords, fn [r, c] -> {r, c} end)
      Server.place_ship(game_id, player_id, coords)
    end)

    case Server.confirm_placement(game_id, player_id) do
      :ok -> {:noreply, socket}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Invalid fleet")}
    end
  end

  defp handle_view({:error, :game_not_found}, socket) do
    socket =
      socket
      |> put_flash(:error, "The match doesn't exist or it already ended.")
      |> push_navigate(to: "/")

    {:ok, socket}
  end

  defp handle_view({:error, :not_allowed}, socket) do
    socket =
      socket
      |> put_flash(:error, "You don't belong to this game.")
      |> push_navigate(to: "/")

    {:ok, socket}
  end

  defp handle_view({:ok, %{phase: :placement, remaining_ms: ms} = view}, socket) do
    connect_to_gameserver(socket.assigns.game_id, socket.assigns.player_id)
    {:ok, assign(socket, view: view, placement_remaining_ms: ms)}
  end

  defp handle_view({:ok, view}, socket) do
    connect_to_gameserver(socket.assigns.game_id, socket.assigns.player_id)
    {:ok, assign(socket, view: view)}
  end

  defp connect_to_gameserver(game_id, player_id) do
    Phoenix.PubSub.subscribe(Battleship.PubSub, "game:#{game_id}")
    Server.connect(game_id, player_id, self())
  end
end
