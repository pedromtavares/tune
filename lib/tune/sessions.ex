defmodule Tune.Sessions do
  alias Tune.Spotify.Supervisor

  def get_cached_data(session_id, debug) do
    case Cachex.get(:session_cache, session_id) do
      {:ok, nil} -> put_cache_data(session_id, debug)
      {:ok, data} -> data
    end
  end

  def put_cache_data(session_id, debug) do
    session =
      if debug do
        from_file(session_id)
      else
        Supervisor.get_session(session_id) && session_map(session_id)
      end

    if session do
      # File.write("sessions/#{session_id}", :erlang.term_to_binary(session), [:binary])
      Cachex.put(:session_cache, session_id, session)
      session
    else
      nil
    end
  end

  def put_cache_playlist(origin_id, target_id, playlist, debug) do
    session_data = get_cached_data(origin_id, debug)
    playlists = Map.get(session_data, :playlists) || %{}
    updated_playlists = Map.put(playlists, target_id, playlist)
    new_session_data = Map.merge(session_data, %{playlists: updated_playlists})
    Cachex.put(:session_cache, origin_id, new_session_data)
  end

  def initial_session(_, debug \\ nil)

  def initial_session(%{id: id} = profile, nil), do: empty_session(id, profile)

  def initial_session(session_id, nil) do
    empty_session(session_id, %{
      avatar_url: "/images/user.png",
      name: "Convidado"
    })
  end

  def initial_session(session_id, _), do: from_file(session_id)

  defp empty_session(id, profile) do
    %{
      profile: profile,
      id: id,
      playlists: %{},
      tracks: %{
        recent: [],
        short: [],
        medium: [],
        long: []
      },
      artists: %{
        short: [],
        medium: [],
        long: []
      }
    }
  end

  defp from_file(session_id) do
    {:ok, content} = File.read("sessions/#{session_id}")

    content
    |> :erlang.binary_to_term()
  end

  defp session_map(session_id) do
    short_tracks_task = Task.async(fn -> get_top_tracks(session_id, "short_term") end)
    medium_tracks_task = Task.async(fn -> get_top_tracks(session_id, "medium_term") end)
    long_tracks_task = Task.async(fn -> get_top_tracks(session_id, "long_term") end)

    recent_tracks_task =
      Task.async(fn -> Tune.spotify_session().recently_played_tracks(session_id, limit: 50) end)

    profile_task = Task.async(fn -> Tune.spotify_session().get_profile(session_id) end)

    short_artists_task = Task.async(fn -> get_top_artists(session_id, "short_term") end)
    medium_artists_task = Task.async(fn -> get_top_artists(session_id, "medium_term") end)
    long_artists_task = Task.async(fn -> get_top_artists(session_id, "long_term") end)

    {:ok, recent_tracks} = Task.await(recent_tracks_task)
    {:ok, short_tracks} = Task.await(short_tracks_task)
    {:ok, medium_tracks} = Task.await(medium_tracks_task)
    {:ok, long_tracks} = Task.await(long_tracks_task)

    profile = Task.await(profile_task)

    {:ok, short_artists} = Task.await(short_artists_task)
    {:ok, medium_artists} = Task.await(medium_artists_task)
    {:ok, long_artists} = Task.await(long_artists_task)

    %{
      id: session_id,
      profile: profile,
      tracks: %{
        recent: recent_tracks,
        short: short_tracks,
        medium: medium_tracks,
        long: long_tracks
      },
      artists: %{
        short: short_artists,
        medium: medium_artists,
        long: long_artists
      }
    }
  end

  defp get_top_tracks(session_id, time_range) do
    opts = [limit: 50, time_range: time_range]
    Tune.spotify_session().top_tracks(session_id, opts)
  end

  defp get_top_artists(session_id, time_range) do
    opts = [limit: 50, time_range: time_range]
    Tune.spotify_session().top_artists(session_id, opts)
  end
end
