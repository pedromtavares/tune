defmodule Tune.Repo.Migrations.AddUniqueIndexToConnections do
  use Ecto.Migration

  def change do
    drop index(:connections, [:origin_id, :target_id])
    create unique_index(:connections, [:origin_id, :target_id])
  end
end
