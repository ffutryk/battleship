defmodule BattleshipWeb.GameLive do
  use BattleshipWeb, :live_view

  alias Battleship.Game.Server
  alias BattleshipWeb.Game.ShipSprites
  import BattleshipWeb.GameComponents

  @impl true
  def mount(%{"id" => id}, session, socket) do
    player_token = session["player_token"]
    game_id = parse_id(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Battleship.PubSub, "game:#{game_id}")
      Server.connect(game_id, player_token, self())
    end

    socket =
      socket
      |> assign(game_id: game_id, player_id: player_token)
      |> apply_view(Server.view(game_id, player_token))

    {:ok, socket}
  end

  @impl true
  def render(%{view: %{phase: :waiting_opponent}} = assigns), do: waiting_phase(assigns)
  def render(%{view: %{phase: :placement}} = assigns), do: placement_phase(assigns)
  def render(%{view: %{phase: :battle}} = assigns), do: battle_phase(assigns)
  def render(%{view: %{phase: :game_over}} = assigns), do: battle_phase(assigns)

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

  defp battle_phase(%{view: %{player_board: %{ships: ships}}} = assigns) do
    assigns = assign(assigns, :own_fleet, ShipSprites.fleet_cells(ships))

    ~H"""
    <main class="relative h-full flex flex-col items-center justify-center">
      <div class="flex flex-col md:flex-row">
        <div class="flex flex-col gap-2 items-center justify-center">
          <h2 :if={@view.is_turn?}>Attack!</h2>
          <h2 :if={!@view.is_turn?}>Opponent's turn</h2>
          <div class="flex flex-col lg:flex-row items-center lg:items-start gap-8">
            <.board
              id="enemy-board"
              phx_hook="HoverTracker"
              active={@view.is_turn?}
              cell_class="hover:brightness-150"
              phx_click={if @view.is_turn?, do: "fire"}
              shots={@view.player_shots}
            />
          </div>
        </div>
        <div class="flex flex-col justify-center items-center">
          <.board
            id="own-board"
            phx_hook="OpponentCursor"
            active={!@view.is_turn?}
            class="[zoom:0.5]"
            shots={@view.enemy_shots}
            ships={@own_fleet}
            own?
          />
        </div>
      </div>

      <div
        :if={@view.phase == :game_over}
        class="absolute inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
      >
        <div class="bg-gray-900 border-4 border-gray-700 p-8 rounded flex flex-col items-center gap-6 shadow-2xl">
          <h2 class="text-4xl text-white">Game Over!</h2>
          <p class="text-2xl text-white">
            {if @view.winner_id == @player_id, do: "You won!", else: "You lost!"}
          </p>
          <div class="flex flex-col gap-4">
            <.button phx-click="go_home" class="btn-pixel w-fit px-8 mt-4">
              Back To Home
            </.button>
          </div>
        </div>
      </div>
    </main>
    """
  end

  @impl true
  def handle_info({:phase_changed, :placement, remaining_ms}, socket) do
    %{game_id: game_id, player_id: player_id} = socket.assigns

    socket =
      socket
      |> apply_view(Server.view(game_id, player_id))
      |> assign(:placement_remaining_ms, remaining_ms)

    {:noreply, socket}
  end

  def handle_info({:phase_changed, :game_over, _winner_id}, socket) do
    %{game_id: game_id, player_id: player_id} = socket.assigns

    socket =
      socket
      |> apply_view(Server.view(game_id, player_id))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:phase_changed, _phase}, socket) do
    %{game_id: game_id, player_id: player_id} = socket.assigns

    socket =
      socket
      |> apply_view(Server.view(game_id, player_id))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:opponent_hover, from_id, {row, col}}, socket) do
    if from_id != socket.assigns.player_id do
      {:noreply, push_event(socket, "opponent_hover", %{row: row, col: col})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:shot, socket) do
    %{game_id: game_id, player_id: player_id} = socket.assigns
    socket = apply_view(socket, Server.view(game_id, player_id))
    {:noreply, socket}
  end

  @impl true
  def handle_event("hover_cell", %{"row" => row, "col" => col}, socket) do
    %{game_id: game_id, player_id: player_id} = socket.assigns
    coord = {row, col}

    Phoenix.PubSub.broadcast_from(
      Battleship.PubSub,
      self(),
      "game:#{game_id}",
      {:opponent_hover, player_id, coord}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_placement", %{"ships" => ships}, socket) do
    %{player_id: player_id, game_id: game_id} = socket.assigns

    Enum.each(ships, fn ship_coords ->
      coords = Enum.map(ship_coords, fn [r, c] -> {r, c} end)
      Server.place_ship(game_id, player_id, coords)
    end)

    case Server.confirm_placement(game_id, player_id) do
      :ok -> {:noreply, socket}
      {:error, _reason} -> {:noreply, put_flash(socket, :error, "Invalid fleet")}
    end
  end

  @impl true
  def handle_event("fire", %{"row" => row, "col" => col}, socket) do
    %{game_id: game_id, player_id: player_id} = socket.assigns
    coord = {String.to_integer(row), String.to_integer(col)}

    case Server.shoot_at(game_id, player_id, coord) do
      {:error, _reason} ->
        {:noreply, socket}

      _shot_state ->
        socket = apply_view(socket, Server.view(game_id, player_id))
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("go_home", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  defp apply_view(socket, {:error, :game_not_found}) do
    socket
    |> put_flash(:error, "The match doesn't exist or it already ended.")
    |> push_navigate(to: "/")
  end

  defp apply_view(socket, {:error, :not_allowed}) do
    socket
    |> put_flash(:error, "You don't belong to this game.")
    |> push_navigate(to: "/")
  end

  defp apply_view(socket, {:ok, %{phase: :placement, remaining_ms: ms} = view}) do
    fleet = build_fleet(view.player_board.available_ships)

    assign(socket,
      view: view,
      placement_remaining_ms: ms,
      fleet: fleet,
      fleet_json: Jason.encode!(fleet)
    )
  end

  defp apply_view(socket, {:ok, view}) do
    assign(socket, view: view)
  end

  defp build_fleet(ships) do
    Enum.map(ships, fn length ->
      %{length: length, sprites: BattleshipWeb.Game.ShipSprites.for_length(length)}
    end)
  end

  defp parse_id(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> id
    end
  end
end
