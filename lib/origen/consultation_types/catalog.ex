defmodule Origen.ConsultationTypes.Catalog do
  @moduledoc """
  Replaceable operation boundary for consultation-type catalog snapshots.
  """

  @type operation :: {:list, %{required(:professional_reference) => String.t()}}
  @type snapshot :: %{
          required(:source) => atom(),
          required(:professional_reference) => String.t(),
          required(:agenda_interval_minutes) => pos_integer(),
          required(:consultation_types) => [map()]
        }
  @type error :: :unavailable | term()

  @callback execute(operation()) :: {:ok, snapshot()} | {:error, error()}

  @spec execute(operation()) :: {:ok, snapshot()} | {:error, error()}
  def execute(operation) do
    case Application.get_env(:origen, :consultation_type_catalog_adapter) do
      adapter when is_atom(adapter) and not is_nil(adapter) -> adapter.execute(operation)
      _other -> {:error, :unavailable}
    end
  end
end
