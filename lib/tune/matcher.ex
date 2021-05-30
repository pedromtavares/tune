defmodule Tune.Matcher do
  @limit 30
  @limit_tracks_per_artist 5
  @artist_score 5
  @track_score 2.5

  def basic_match(%{id: id}, %{id: id2}, _) when id == id2, do: %{}

  def basic_match(
        %{artists: origin_artists, tracks: origin_tracks},
        %{artists: target_artists, tracks: target_tracks},
        nil
      ) do
    all_origin_tracks = get_all_items(origin_tracks)
    all_target_tracks = get_all_items(target_tracks)

    all_origin_artists = get_all_items(origin_artists)
    all_target_artists = get_all_items(target_artists)

    tracks = intersection(all_origin_tracks, all_target_tracks)
    artists = intersection(all_origin_artists, all_target_artists)

    %{
      tracks: tracks,
      artists: artists,
      score: score_for(tracks, artists)
    }
  end

  def basic_match(origin, target, _), do: match(origin, target)

  def match(%{id: id}, %{id: id2}) when id == id2, do: %{}

  def match(
        %{artists: origin_artists, tracks: origin_tracks, profile: %{id: session_id}},
        %{artists: target_artists, tracks: target_tracks}
      ) do
    all_origin_tracks = get_all_items(origin_tracks)
    all_target_tracks = get_all_items(target_tracks)

    all_origin_artists = get_all_items(origin_artists)
    all_target_artists = get_all_items(target_artists)

    tracks = intersection(all_origin_tracks, all_target_tracks)
    artists = intersection(all_origin_artists, all_target_artists)
    from_artists = get_artist_tracks(artists, all_origin_tracks, all_target_tracks)
    by_artists = group_tracks_by_artists(artists, from_artists)
    matched_ids = Enum.map(tracks, & &1.id)

    chosen =
      chosen_tracks(tracks, by_artists, session_id)
      |> add_recommendations(artists, all_origin_artists, all_target_artists, session_id)
      |> tracks_with_audio_features(session_id)
      |> final_sort(matched_ids)

    %{
      tracks: tracks,
      artists: artists,
      from_artists: from_artists,
      chosen: chosen,
      by_artists: group_tracks_by_artists(artists, chosen),
      score: score_for(tracks, artists)
    }
  end

  defp get_all_items(session_map) do
    session_map
    |> Enum.reduce([], fn {_key, val}, acc -> acc ++ val end)
    |> Enum.uniq_by(& &1.id)
  end

  defp intersection(origin, target) do
    ids = Enum.map(origin, & &1.id)
    Enum.filter(target, fn track -> Enum.member?(ids, track.id) end)
  end

  defp get_artist_tracks(artists, origin_tracks, target_tracks) do
    all_tracks = Enum.shuffle(origin_tracks ++ target_tracks)

    Enum.reduce(artists, [], fn artist, acc ->
      acc ++ tracks_by_artist_id(all_tracks, artist.id)
    end)
    |> Enum.uniq_by(& &1.id)
  end

  defp group_tracks_by_artists(artists, tracks) do
    Enum.reduce(artists, %{}, fn artist, acc ->
      artist_tracks = tracks_by_artist_id(tracks, artist.id)
      Map.put(acc, artist.id, artist_tracks)
    end)
  end

  defp chosen_tracks(matched_tracks, by_artists, session_id) do
    chosen = matched_tracks
    chosen_ids = Enum.map(chosen, & &1.id)

    {list, pool} =
      Enum.reduce(by_artists, {chosen, by_artists}, fn {artist_id, _},
                                                       {picked_tracks, new_by_artists} = acc ->
        current_pool =
          Enum.filter(Map.get(new_by_artists, artist_id), fn track ->
            !Enum.member?(chosen_ids, track.id)
          end)

        cond do
          length(picked_tracks) >= @limit ||
              length(tracks_by_artist_id(picked_tracks, artist_id)) >= @limit_tracks_per_artist ->
            acc

          length(current_pool) > 0 ->
            {track, new_pool} = List.pop_at(current_pool, 0)
            {uniq_tracks(picked_tracks ++ [track]), Map.put(new_by_artists, artist_id, new_pool)}

          true ->
            popular = popular_tracks(session_id, artist_id)
            {track, new_pool} = List.pop_at(popular, 0)
            {uniq_tracks(picked_tracks ++ [track]), Map.put(new_by_artists, artist_id, new_pool)}
        end
      end)

    if length(list) == length(matched_tracks) || length(list) >= @limit do
      list
    else
      chosen_tracks(list, pool, session_id)
    end
  end

  def add_recommendations(tracks, artists, origin_artists, target_artists, session_id)
      when length(artists) == 0 do
    rest = @limit - length(tracks)

    artists = Enum.take(origin_artists, 5) ++ Enum.take(target_artists, 5)

    tracks ++ recommended_tracks(session_id, artists, rest)
  end

  def add_recommendations(tracks, artists, _, _, session_id) do
    rest = @limit - length(tracks)

    tracks ++ recommended_tracks(session_id, artists, rest)
  end

  defp recommended_tracks(session_id, artists, limit) when limit > 0 do
    artist_ids = artists |> Enum.take(5) |> Enum.map(& &1.id)

    Tune.spotify_session().get_recommendations_from_artists(session_id, artist_ids, limit)
    |> elem(1)
  end

  defp recommended_tracks(_, _, _), do: []

  defp popular_tracks(session_id, artist_id) do
    {:ok, tracks} = Tune.spotify_session().get_popular_tracks(session_id, artist_id)
    IO.inspect(Enum.map(tracks, & &1.name) |> Enum.join(", "))
    tracks
  end

  defp tracks_with_audio_features(tracks, session_id)
       when length(tracks) > 0 and length(tracks) < 100 do
    Tune.spotify_session().audio_features(session_id, tracks)
    |> elem(1)
  end

  defp tracks_with_audio_features(_, _), do: []

  defp final_sort(all_tracks, chosen_ids) do
    sorted_by_energy =
      Enum.sort_by(
        all_tracks,
        fn track ->
          track.audio_features["energy"]
        end,
        :desc
      )

    chosen = Enum.filter(sorted_by_energy, fn track -> Enum.member?(chosen_ids, track.id) end)
    mid_result = sorted_by_energy -- chosen
    uniq_tracks(chosen ++ mid_result)
  end

  defp uniq_tracks(tracks) do
    Enum.uniq_by(tracks, & &1.id)
  end

  defp tracks_by_artist_id(tracks, artist_id) do
    Enum.filter(tracks, fn track ->
      Enum.member?(Enum.map(track.artists, & &1.id), artist_id)
    end)
  end

  defp score_for(tracks, artists) do
    result = round(length(tracks) * @track_score) + length(artists) * @artist_score
    if result > 100, do: 100, else: result
  end
end
