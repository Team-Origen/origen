defmodule Origen.Repo.Migrations.AddSessionsInvalidatedAtToPatientProfiles do
  use Ecto.Migration

  def change do
    alter table(:patient_profiles) do
      add :sessions_invalidated_at, :timestamptz
    end
  end
end
