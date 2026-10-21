defmodule OrigenWeb.ProfessionalProfilePreview do
  @moduledoc """
  Fictional fixtures shared by the settings summary and profile editor.
  This module has no persistence and is not a professional-profile domain context.
  """

  @fields [
    {"first_name", "Nombre"},
    {"last_name", "Apellido"},
    {"specialty", "Especialidad"},
    {"licence_type", "Tipo de matrícula"},
    {"licence_number", "Número de matrícula"}
  ]

  def fields, do: @fields

  def load("load-error"), do: {:error, :simulated}

  def load(scenario) do
    profile = %{
      "first_name" => "Nombre de muestra",
      "last_name" => "Apellido de muestra",
      "specialty" => "",
      "licence_type" => "",
      "licence_number" => ""
    }

    case scenario do
      "empty" ->
        {:ok, Map.new(@fields, fn {field, _} -> {field, ""} end)}

      "complete" ->
        {:ok,
         Map.merge(profile, %{
           "specialty" => "Especialidad de muestra",
           "licence_type" => "Tipo de muestra",
           "licence_number" => "DEMO-001"
         })}

      _ ->
        {:ok, profile}
    end
  end

  def missing_fields(profile) do
    Enum.filter(@fields, fn {field, _} -> String.trim(Map.get(profile, field, "")) == "" end)
  end

  def has_data?(profile) do
    Enum.any?(@fields, fn {field, _} -> String.trim(Map.get(profile, field, "")) != "" end)
  end

  def patient_projection(profile) do
    %{
      name:
        [profile["first_name"], profile["last_name"]]
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join(" "),
      specialty: profile["specialty"] || ""
    }
  end
end
