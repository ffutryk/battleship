defmodule BattleshipWeb.GameLive do
  use BattleshipWeb, :live_view

  alias Battleship.Game.{Server, State}

  @impl true
  def mount(%{"id" => id}, session, socket) do
    player_token = session["player_token"]

    game_id =
      case Integer.parse(id) do
        {int, ""} -> int
        _ -> id
      end

    case Server.get_state(game_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "The match doesn't exist or it already ended.")
          |> push_navigate(to: "/")

        {:ok, socket}

      state ->
        Phoenix.PubSub.subscribe(Battleship.PubSub, "game:#{state.id}")
        Server.connect(game_id, player_token, self())

        {:ok, assign(socket, state: state, player_id: player_token)}
    end
  end

  @impl true
  def render(%{state: %State{phase: :waiting_opponent}} = assigns), do: waiting_phase(assigns)
  def render(%{state: %State{phase: :placement}} = assigns), do: placement_phase(assigns)
  def render(%{state: %State{phase: :battle}} = assigns), do: battle_phase(assigns)

  defp waiting_phase(assigns) do
    ~H"""
    <main class="h-full flex items-center justify-center">
      Waiting for opponent<span class="animate-dots"></span>
    </main>
    """
  end

  defp placement_phase(assigns) do
    board = player_board(assigns.state, assigns.player_id)
    assigns = assign(assigns, :board, board)

    ~H"""
    <main class="h-full flex flex-col items-center justify-center">
      <.timer id="timer-mobile" class="flex md:hidden mb-8" remaining_ms={@placement_remaining_ms} />
      <div class="flex flex-col md:flex-row gap-8">
        <div class="flex flex-col gap-2 items-center justify-center">
          <h2>Build your fleet</h2>
          <div class="flex flex-col lg:flex-row items-center lg:items-start gap-8">
            <div
              id="board"
              class="flex flex-col gap-1 select-none"
            >
              <%= for row <- 0..9 do %>
                <div class="flex gap-1">
                  <div class="grid-cell grid-label">{row_label(row)}</div>
                  <%= for col <- 0..9 do %>
                    <div class="grid-cell bg-grid hover:brightness-125 cursor-pointer" />
                  <% end %>
                  <div class="grid-cell"></div>
                </div>
              <% end %>
              <div class="flex gap-1">
                <div class="grid-cell"></div>
                <%= for col <- 0..9 do %>
                  <div class="grid-cell grid-label">{col + 1}</div>
                <% end %>
                <div class="grid-cell"></div>
              </div>
            </div>
          </div>
        </div>
        <div class="flex flex-col justify-center items-center gap-8">
          <.timer id="timer-desktop" class="hidden md:flex" remaining_ms={@placement_remaining_ms} />
          <div class="flex gap-4">
            <.button id="confirm-btn" class="btn-pixel w-fit px-8" disabled>Confirm</.button>
            <.button id="rotate-btn" class="btn-pixel-icon">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 104 65"
                fill="currentColor"
                class="h-8 w-8"
              >
                <rect x="13" y="13" width="13" height="39" />
                <rect y="13" width="13" height="13" />
                <rect x="13" width="13" height="13" />
                <rect x="26" y="13" width="13" height="13" />
                <rect x="26" y="52" width="26" height="13" />
                <rect x="78" y="13" width="13" height="39" />
                <rect x="91" y="39" width="13" height="13" />
                <rect x="78" y="52" width="13" height="13" />
                <rect x="65" y="39" width="13" height="13" />
                <rect x="52" width="26" height="13" />
              </svg>
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

  defp timer(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="Timer"
      data-remaining-ms={@remaining_ms}
      data-duration-s="30"
      class={["relative items-center justify-center w-32 h-32", Map.get(assigns, :class, "flex")]}
    >
      <svg class="absolute inset-0 w-full h-full rotate-90" viewBox="0 0 100 100">
        <rect
          data-role="progress"
          x="5"
          y="5"
          width="90"
          height="90"
          fill="none"
          stroke="white"
          stroke-width="8"
          pathLength="100"
          stroke-dasharray="100"
          stroke-dashoffset="0"
        />
      </svg>
      <span data-role="seconds" class="text-7xl tracking-[-0.2em] -translate-x-1.5">30</span>
    </div>
    """
  end

  defp row_label(row), do: Enum.at(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"], row)

  @impl true
  def handle_info({:phase_changed, :placement, remaining_ms}, socket) do
    {:noreply,
     socket
     |> update(:state, &%{&1 | phase: :placement})
     |> assign(:placement_remaining_ms, remaining_ms)}
  end

  @impl true
  def handle_info({:phase_changed, new_phase}, socket) do
    {:noreply, update(socket, :state, &%{&1 | phase: new_phase})}
  end

  defp player_board(%State{boards: boards}, player_id) do
    Map.get(boards, player_id)
  end

  @impl true
  def handle_event("confirm_placement", %{"ships" => ships}, socket) do
    player_id = socket.assigns.player_id
    game_id = socket.assigns.state.id

    Enum.each(ships, fn ship_coords ->
      coords = Enum.map(ship_coords, fn [r, c] -> {r, c} end)
      Server.place_ship(game_id, player_id, coords)
    end)

    case Server.confirm_placement(game_id, player_id) do
      :ok -> {:noreply, socket}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Invalid fleet")}
    end
  end
end
