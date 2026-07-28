defmodule BattleshipWeb.HomeLive do
  use BattleshipWeb, :live_view

  def render(assigns) do
    ~H"""
    <main class="min-h-dvh flex flex-col items-center justify-center bg-ocean font-silkscreen px-4 gap-8">
      <div class="inline-flex justify-center items-start text-[clamp(3rem,14vw,8rem)]">
        <h1 class="text-hull tracking-[-0.2em]  stroke-text">
          BATTLESHIP
        </h1>
        <span class="ml-[0.05em] text-[0.5em] tracking-[-0.1em] leading-none">TM</span>
      </div>
      <.button class="btn-pixel">Play as Guest</.button>
    </main>
    """
  end
end
