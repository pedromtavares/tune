defmodule Tune.Repo.Migrations.AddAutoSyncToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:auto_sync, :boolean, default: true)
    end
  end
end
