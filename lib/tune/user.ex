defmodule Tune.User do
  use Tune.Schema

  schema "users" do
    field(:spotify_id, :string)
    field(:last_online_at, :utc_datetime)

    belongs_to(:inviter, Tune.User)

    has_many(:connections, Tune.Connection, foreign_key: :origin_id)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :spotify_id,
      :last_online_at,
      :inviter_id
    ])
  end
end
