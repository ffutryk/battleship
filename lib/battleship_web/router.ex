defmodule BattleshipWeb.Router do
  use BattleshipWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BattleshipWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", BattleshipWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/games/:id", GameLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", BattleshipWeb do
  #   pipe_through :api
  # end
end
