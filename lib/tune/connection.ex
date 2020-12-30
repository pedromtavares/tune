defmodule Tune.Connection do
  use Tune.Schema

  schema "connections" do
    field(:score, :integer)
    field(:created_playlist, :boolean)
    field(:matched_artists_count, :integer)
    field(:matched_tracks_count, :integer)

    belongs_to(:origin, Tune.User)
    belongs_to(:target, Tune.User)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :score,
      :matched_artists_count,
      :matched_tracks_count,
      :created_playlist,
      :origin_id,
      :target_id,
      :updated_at
    ])
  end
end
