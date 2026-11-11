defmodule OrigenWeb.ProfessionalProfileForm do
  @moduledoc "Presentation of persisted professional profiles, shared by settings and the editor."

  @fields [
    {"first_name", "Nombre"},
    {"last_name", "Apellido"},
    {"specialty", "Especialidad"},
    {"license_type", "Tipo de matrícula"},
    {"license_number", "Número de matrícula"}
  ]

  def fields, do: @fields

  def from_profile(profile) do
    Map.new(@fields, fn {field, _} ->
      {field, if(profile, do: Map.get(profile, String.to_existing_atom(field)) || "", else: "")}
    end)
  end

  def missing_fields(profile),
    do: Enum.filter(@fields, fn {field, _} -> String.trim(profile[field] || "") == "" end)

  def has_data?(profile),
    do: Enum.any?(@fields, fn {field, _} -> String.trim(profile[field] || "") != "" end)

  def patient_projection(profile) do
    %{
      name:
        [profile["first_name"], profile["last_name"]]
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join(" "),
      specialty: profile["specialty"] || ""
    }
  end

  def context,
    do: Application.get_env(:origen, :professional_profiles_context, Origen.ProfessionalProfiles)
end
