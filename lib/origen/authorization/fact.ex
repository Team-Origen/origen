defmodule Origen.Authorization.Fact do
  @moduledoc "Explicit policy knowledge for one authorization dimension."

  @type t(value) :: {:known, value} | :unknown | :not_applicable
  @type t :: t(term())

  @spec known(value) :: t(value) when value: term()
  def known(value), do: {:known, value}

  @spec valid?(term()) :: boolean()
  def valid?({:known, _value}), do: true
  def valid?(:unknown), do: true
  def valid?(:not_applicable), do: true
  def valid?(_value), do: false
end
