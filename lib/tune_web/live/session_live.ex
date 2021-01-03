defmodule TuneWeb.SessionLive do
  use Phoenix.LiveView

  alias TuneWeb.SessionView
  alias Tune.{Matcher, Sessions}

  def mount(_, session, socket) do
    case Tune.Auth.load_user(session) do
      {:authenticated, session_id, session_user} ->
        if connected?(socket) do
          TuneWeb.subscribe("session-#{session_id}")
        end

        Process.send_after(self(), :build_current_session, 100)

        current_user = Tune.get_user_by_spotify_id(session_id)

        {:ok,
         socket
         |> assign(
           current_session_id: session_id,
           session_user: session_user,
           current_session: Sessions.initial_session(session_user),
           current_user: current_user,
           qr_code: TuneWeb.session_qr_code(socket, session_id),
           playlist: nil,
           creating: current_user.auto_sync,
           redirects: [],
           last_session_id: Tune.latest_session_id(current_user)
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
       show_share: is_current,
       show_history: false,
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

  def handle_event("auto-sync", params, socket) do
    user = Tune.toggle_auto_sync(socket.assigns.current_session_id, params)
    {:noreply, assign(socket, current_user: user)}
  end

  def handle_event("show-history", _, socket) do
    {:noreply, assign(socket, show_history: true, show_share: false)}
  end

  def handle_event("show-share", _, socket) do
    {:noreply, assign(socket, show_share: true, show_history: false)}
  end

  def handle_event("show-sync", _, socket) do
    {:noreply, assign(socket, show_share: false, show_history: false)}
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
       |> push_patch(to: "/#{socket.assigns.current_session_id}")}
    end
  end

  def handle_info(:create_playlist, %{assigns: assigns} = socket) do
    playlist = Tune.create_playlist(assigns.current_session, assigns.session)

    Task.start(fn -> Tune.follow_good_vibes(assigns.current_session_id) end)

    Tune.Sessions.put_cache_playlist(
      assigns.current_session_id,
      assigns.session.id,
      playlist,
      assigns.debug
    )

    # unless assigns.current_user.auto_sync do
    #   Process.send_after(self(), {:redirect_to_playlist, playlist}, 1000)
    # end

    {:noreply, assign(socket, playlist: playlist)}
  end

  def handle_info({"redirect", %{from: session_id}}, %{assigns: assigns} = socket) do
    if session_id != assigns.session.id && !Enum.member?(assigns.redirects, session_id) do
      redirects = [session_id] ++ assigns.redirects

      {:noreply,
       socket
       |> assign(redirects: redirects)
       |> push_patch(to: "/#{session_id}")}
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

      Process.send_after(self(), {:broadcast_to_connection, session_id}, 2000)

      playlists = Map.get(assigns.current_session, :playlists)
      playlist = playlists && Map.get(playlists, session_id)

      if assigns.current_user.auto_sync && !playlist do
        Process.send(self(), :create_playlist, [])
      end

      {:noreply,
       assign(socket,
         session: session,
         match: match,
         creating: assigns.current_user.auto_sync,
         playlist: playlist,
         last_session_id: session_id
       )}
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         "O perfil que você tentou acessar não está disponível, por favor, tente novamente."
       )
       |> push_patch(to: "/#{assigns.current_session_id}")}
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
