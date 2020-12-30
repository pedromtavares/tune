defmodule TuneWeb.SessionView do
  @moduledoc false
  use TuneWeb, :view

  @default_medium_thumbnail "https://via.placeholder.com/150"
  @default_artwork "https://via.placeholder.com/300"

  alias Tune.Spotify.Schema
  alias Schema.{Artist, Track}

  def score_label(score) when score > 75, do: "FORTE"
  def score_label(score) when score > 50, do: "ALTA"
  def score_label(score) when score > 25, do: "BOA"
  def score_label(score) when score > 0, do: "LEVE"

  def name(%Track{name: name}), do: name
  def name(%Artist{name: name}), do: name

  defp authors(%Track{artists: artists}) do
    artists
    |> Enum.map(fn artist ->
      artist.name
    end)
    |> Enum.intersperse(", ")
  end

  defp artwork(%Artist{thumbnails: thumbnails}),
    do: Map.get(thumbnails, :medium, @default_artwork)

  def user_avatar(user) do
    case user.avatar_url do
      nil -> fallback_avatar(user.name)
      url -> url
    end
  end

  def first_names(%{profile: %{name: name1}}, %{profile: %{name: name2}}) do
    "#{first_name(name1)} & #{first_name(name2)}"
  end

  def first_name(name1) do
    String.split(name1, " ") |> List.first()
  end

  defp fallback_avatar(name) do
    "https://via.placeholder.com/45?text=" <> String.first(name)
  end

  defp thumbnail(%Track{album: album}),
    do: resolve_thumbnail(album.thumbnails, [:medium, :large])

  defp thumbnail(%Artist{thumbnails: thumbnails}),
    do: resolve_thumbnail(thumbnails, [:medium, :large])

  defp resolve_thumbnail(thumbnails, preferred_sizes) do
    Enum.find_value(thumbnails, @default_medium_thumbnail, fn {size, url} ->
      if size in preferred_sizes, do: url
    end)
  end
end
