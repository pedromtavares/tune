defmodule TuneWeb.AuthController do
  @moduledoc """
  Controls authentication via the Spotify API.
  """
  use TuneWeb, :controller

  plug Ueberauth

  @spec callback(Plug.Conn.t(), any) :: Plug.Conn.t()
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_id = get_in(auth.extra.raw_info, [:user, "id"])

    target_session_id = get_session(conn, :target_session_id)

    Tune.create_user(user_id, target_session_id)

    session_id =
      if target_session_id do
        target_session_id
      else
        user_id
      end

    conn
    |> put_session(:spotify_credentials, auth.credentials)
    |> put_session(:spotify_id, auth.info.nickname)
    |> configure_session(renew: true)
    |> redirect(to: "/#{session_id}")
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Erro de autenticação, por favor, tente novamente")
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  def new(conn, _params) do
    session_id = get_session(conn, :current_session_id)

    if session_id do
      redirect(conn, to: "/#{session_id}")
    else
      target_session =
        get_session(conn, :target_session_id) |> Tune.Spotify.Supervisor.get_session()

      render(conn, "new.html", session: target_session)
    end
  end

  @spec delete(Plug.Conn.t(), any) :: Plug.Conn.t()
  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Saiu.")
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  @spec ensure_authenticated(Plug.Conn.t(), any) :: Plug.Conn.t()
  def ensure_authenticated(conn, _opts) do
    session = get_session(conn)

    case Tune.Auth.load_user(session) do
      {:authenticated, session_id, user} ->
        conn
        |> assign(:status, :authenticated)
        |> assign(:user, user)
        |> assign(:session_id, session_id)
        |> put_session(:current_session_id, session_id)

      {:error, :not_authenticated} ->
        conn
        |> assign(:status, :not_authenticated)
        |> put_session(:target_session_id, conn.path_params["session_id"])
        |> Phoenix.Controller.redirect(to: "/")
        |> halt()
    end
  end
end
