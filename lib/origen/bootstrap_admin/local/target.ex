defmodule Origen.BootstrapAdmin.Local.Target do
  @moduledoc false

  defstruct [:id, :role, :state]

  def new(nil), do: nil
  def new(%{id: id}), do: %__MODULE__{id: id, role: :administrator, state: :pending_activation}

  defimpl Inspect do
    def inspect(%{id: id}, _opts), do: "#Origen.BootstrapAdmin.Local.Target<id: #{id}>"
  end
end
