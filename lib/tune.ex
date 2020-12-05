defmodule Tune do
  alias Tune.{Repo, User, Connection}

  def get_user_by_spotify_id(spotify_id) do
    Repo.get_by(User, spotify_id: spotify_id)
  end

  def get_connection(origin_user, target_user) do
    Repo.get_by(Connection, origin_id: origin_user.id, target_id: target_user.id)
  end

  def create_user(session_id, inviter_session_id) do
    exists = get_user_by_spotify_id(session_id)

    if exists do
      User.changeset(exists, %{last_online_at: DateTime.utc_now()})
      |> Repo.update!()
    else
      inviter = inviter_session_id && get_user_by_spotify_id(inviter_session_id)

      User.changeset(%User{}, %{
        spotify_id: session_id,
        inviter_id: inviter && inviter.id,
        last_online_at: DateTime.utc_now()
      })
      |> Repo.insert!()
    end
  end

  def toggle_auto_sync(session_id, params) do
    exists = get_user_by_spotify_id(session_id)

    User.changeset(exists, %{auto_sync: Map.has_key?(params, "value")})
    |> Repo.update!()
  end

  def connect_users(origin_session_id, target_session_id, match, created_playlist \\ false) do
    origin = create_user(origin_session_id, nil)
    target = create_user(target_session_id, origin_session_id)
    exists = get_connection(origin, target)

    if exists do
      Connection.changeset(exists, %{
        score: match.score,
        matched_artists_count: length(match.artists),
        matched_tracks_count: length(match.tracks),
        created_playlist: created_playlist
      })
      |> Repo.update()
    else
      Connection.changeset(%Connection{}, %{
        origin_id: origin.id,
        target_id: target.id,
        score: match.score,
        matched_artists_count: length(match.artists),
        matched_tracks_count: length(match.tracks)
      })
      |> Repo.insert()
    end
  end
end
