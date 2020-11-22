defmodule TuneWeb.SessionLive do
  use Phoenix.LiveView

  alias TuneWeb.SessionView
  alias Tune.{Matcher, Sessions}

  def mount(_, session, socket) do
    case Tune.Auth.load_user(session) do
      {:authenticated, session_id, user} ->
        if connected?(socket) do
          TuneWeb.subscribe("session-#{session_id}")
        end

        Process.send_after(self(), :build_current_session, 100)

        {:ok,
         socket
         |> assign(
           current_session_id: session_id,
           user: user,
           current_session: Tune.Sessions.initial_session(user),
           qr_code: Sessions.generate_code(session_id),
           playlist: nil,
           creating: false,
           redirects: []
         )}

      _error ->
        {:ok, redirect(socket, to: "/")}
    end
  end

  def handle_params(%{"session_id" => session_id} = params, _url, socket) do
    is_current = session_id == socket.assigns.current_session_id

    unless is_current, do: Process.send_after(self(), {:build_session, session_id}, 500)

    {:noreply,
     assign(socket,
       session: Sessions.initial_session(session_id, params["debug"]),
       debug: params["debug"],
       is_current: is_current,
       match: %{
         tracks: [],
         chosen: [],
         artists: [],
         from_artists: [],
         by_artists: [],
         score: nil
       }
     )}
  end

  def handle_event("playlist", _, socket) do
    origin = socket.assigns.current_session
    target = socket.assigns.session

    if origin && target do
      Process.send(self(), :create_playlist, [])
      {:noreply, assign(socket, creating: true)}
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         "Um dos participantes ficou offline, por favor, tente novamente."
       )
       |> push_patch(to: "/sessions/#{socket.assigns.current_session_id}")}
    end
  end

  def handle_info(:create_playlist, %{assigns: assigns} = socket) do
    playlist = Matcher.create_playlist(assigns.current_session, assigns.session)

    Process.send_after(self(), {:redirect_to_playlist, playlist}, 1000)

    {:noreply, assign(socket, playlist: playlist)}
  end

  def handle_info({"redirect", %{from: session_id}}, %{assigns: assigns} = socket) do
    if session_id != assigns.session.id && !Enum.member?(assigns.redirects, session_id) do
      redirects = [session_id] ++ assigns.redirects

      {:noreply,
       socket
       |> assign(redirects: redirects)
       |> push_patch(to: "/sessions/#{session_id}")}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:build_current_session, socket) do
    {:noreply,
     assign(socket,
       current_session:
         Sessions.get_cached_data(socket.assigns.current_session_id, socket.assigns.debug)
     )}
  end

  def handle_info({:build_session, session_id}, %{assigns: assigns} = socket) do
    session = Sessions.get_cached_data(session_id, assigns.debug)

    if session do
      match = Matcher.basic_match(assigns.current_session, session, assigns.debug)
      Tune.connect_users(assigns.current_session_id, session_id, match)

      Process.send_after(self(), {:broadcast_to_connection, session_id}, 100)

      {:noreply,
       assign(socket,
         session: session,
         match: match
       )}
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         "O perfil que você tentou acessar não está disponível, por favor, tente novamente."
       )
       |> push_patch(to: "/sessions/#{assigns.current_session_id}")}
    end
  end

  def handle_info({:redirect_to_playlist, playlist}, socket) do
    {:noreply, socket |> redirect(external: playlist.uri)}
  end

  def handle_info({:broadcast_to_connection, session_id}, socket) do
    Process.send_after(self(), {:broadcast_to_connection, session_id}, 10_000)

    TuneWeb.broadcast("session-#{session_id}", "redirect", %{
      from: socket.assigns.current_session_id
    })

    {:noreply, socket}
  end

  def render(assigns) do
    SessionView.render("show.html", assigns)
  end
end
