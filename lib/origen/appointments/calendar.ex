defmodule Origen.Appointments.Calendar do
  @moduledoc """
  Domain boundary for querying appointment availability and calendar schedules.
  Allows non-production mock adapters for UI development while enforcing fail-closed
  adapter configuration in production.
  """

  @type slot :: %{
          required(:id) => String.t(),
          required(:start_time) => Time.t(),
          required(:end_time) => Time.t(),
          required(:start_formatted) => String.t(),
          required(:end_formatted) => String.t(),
          required(:status) => :available | :reserved
        }

  @type cancellation_policy :: %{
          required(:cutoff_description) => String.t(),
          required(:penalty_percentage) => integer(),
          required(:penalty_description) => String.t()
        }

  @type daily_schedule :: %{
          required(:date) => Date.t(),
          required(:professional_id) => String.t(),
          required(:professional_name) => String.t(),
          required(:specialty) => String.t(),
          required(:slots) => [slot()],
          required(:cancellation_policy) => cancellation_policy()
        }

  @type professional_summary :: %{
          required(:id) => String.t(),
          required(:name) => String.t(),
          required(:specialty) => String.t()
        }

  @callback get_daily_schedule(professional_id :: String.t(), date :: Date.t()) ::
              {:ok, daily_schedule()} | {:error, :unavailable | :invalid_professional | term()}

  @callback list_professionals() :: {:ok, [professional_summary()]} | {:error, term()}

  @spec get_daily_schedule(String.t(), Date.t()) ::
          {:ok, daily_schedule()} | {:error, :unavailable | term()}
  def get_daily_schedule(professional_id, date) do
    case adapter() do
      nil -> {:error, :unavailable}
      mod -> mod.get_daily_schedule(professional_id, date)
    end
  end

  @spec list_professionals() :: {:ok, [professional_summary()]} | {:error, :unavailable | term()}
  def list_professionals do
    case adapter() do
      nil -> {:error, :unavailable}
      mod -> mod.list_professionals()
    end
  end

  defp adapter do
    Application.get_env(:origen, :appointments_calendar_adapter)
  end
end
