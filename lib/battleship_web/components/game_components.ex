defmodule BattleshipWeb.GameComponents do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :string, default: nil
  attr :phx_hook, :string, default: nil
  attr :phx_click, :string, default: nil
  attr :cell_class, :string, default: nil
  attr :shots, :map, default: %{}
  attr :ships, :map, default: %{}
  attr :own?, :boolean, default: false
  attr :active, :boolean, default: true

  def board(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook={@phx_hook}
      data-active={to_string(@active)}
      class={["flex flex-col gap-1 select-none relative", @class]}
    >
      <div :for={row <- 0..9} class="flex gap-1">
        <div class="grid-cell grid-label">{row_label(row)}</div>
        <div
          :for={col <- 0..9}
          data-row={row}
          data-col={col}
          phx-value-row={row}
          phx-value-col={col}
          phx-click={@phx_click}
          class={["grid-cell bg-grid cursor-pointer", @cell_class]}
        >
          <% ship_cell = @ships[{row, col}] %>
          <% shot = @shots[{row, col}] %>
          <img
            :if={ship_cell && !shot}
            src={ship_cell.src}
            style={ship_cell.style}
            class="inset-0 w-full h-full object-cover pointer-events-none"
          />
          <img :if={shot} src={BattleshipWeb.Game.PegSprites.sprite_for(shot, @own?)} />
        </div>
        <div class="grid-cell"></div>
      </div>
      <div class="flex gap-1">
        <div class="grid-cell"></div>
        <div :for={col <- 0..9} class="grid-cell grid-label">{col + 1}</div>
        <div class="grid-cell"></div>
      </div>
    </div>
    """
  end

  def timer(assigns) do
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

  def rotate_icon(assigns) do
    ~H"""
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
    """
  end

  defp row_label(row), do: Enum.at(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"], row)
end
