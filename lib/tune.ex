defmodule Tune do
  alias Tune.{Repo, User, Connection, Matcher}
  import Ecto.Query, only: [from: 2]

  def spotify_session, do: Application.get_env(:tune, :spotify_session)

  def get_user_by_spotify_id(spotify_id) do
    Repo.get_by(User, spotify_id: spotify_id)
  end

  def get_connection(origin_user, target_user) do
    Repo.get_by(Connection, origin_id: origin_user.id, target_id: target_user.id)
  end

  def latest_session_id(%{id: user_id}) do
    ago = Timex.now() |> Timex.shift(minutes: -60)

    conn =
      from(connection in Connection,
        limit: 1,
        where: connection.origin_id == ^user_id,
        where: connection.updated_at > ^ago,
        order_by: [desc: connection.updated_at]
      )
      |> Repo.all()
      |> Repo.preload(:target)
      |> List.first()

    conn && conn.target.spotify_id
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
        created_playlist: created_playlist,
        updated_at: Timex.now()
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

  def follow_good_vibes(session_id), do: spotify_session().follow_good_vibes(session_id)

  def create_playlist(origin, target) do
    matched = Matcher.match(origin, target)

    connection =
      case Tune.connect_users(origin.id, target.id, matched, true) do
        {:ok, connection} -> connection
        _ -> %{id: origin.id}
      end

    now = Date.utc_today()
    date = "#{now.day}/#{now.month}/#{now.year}"
    name = "Sinttonia.com - #{first_name(origin.profile)} & #{first_name(target.profile)}"

    description =
      if length(matched.artists) > 0 do
        "Criada em #{date} com o melhor de #{artists_label(matched.artists)}. ID ##{connection.id}"
      else
        "Criada em #{date}. ID ##{connection.id}"
      end

    case spotify_session().create_playlist(origin.id, name, description, matched.chosen) do
      {:ok, playlist} -> playlist
      _ -> nil
    end
  end

  defp first_name(%{name: name}) do
    name
    |> String.split(" ")
    |> List.first()
  end

  defp artists_label(matched_artists) do
    artists = matched_artists |> Enum.take(5) |> Enum.map(& &1.name)
    last = List.last(artists)

    case length(artists) do
      5 -> "#{Enum.join(Enum.take(artists, 4), ", ")} e #{last}"
      4 -> "#{Enum.join(Enum.take(artists, 3), ", ")} e #{last}"
      3 -> "#{Enum.join(Enum.take(artists, 2), ", ")} e #{last}"
      2 -> "#{List.first(artists)} e #{last}"
      _ -> last
    end
  end
end
