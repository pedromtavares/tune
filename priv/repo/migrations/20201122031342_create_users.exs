defmodule Tune.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:spotify_id, :string)
      add(:last_online_at, :utc_datetime)
      add(:inviter_id, references(:users))

      timestamps()
    end

    create table(:connections) do
      add(:origin_id, references(:users, on_delete: :delete_all))
      add(:target_id, references(:users, on_delete: :delete_all))
      add(:score, :integer)
      add(:matched_artists_count, :integer)
      add(:matched_tracks_count, :integer)
      add(:created_playlist, :boolean, default: false)

      timestamps()
    end

    create index(:users, [:spotify_id])
    create index(:connections, [:origin_id, :target_id])
  end
end
