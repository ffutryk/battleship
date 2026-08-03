defmodule BattleshipWeb.Plugs.EnsurePlayer do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :player_token) do
      nil ->
        token = "guest_" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)

        conn
        |> put_session(:player_token, token)
        |> assign(:player_token, token)

      token ->
        assign(conn, :player_token, token)
    end
  end
end
