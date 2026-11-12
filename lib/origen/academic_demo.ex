defmodule Origen.AcademicDemo do
  @moduledoc """
  Academic demo mode: lets internal staff (administrator, professional, secretary)
  sign in and activate their accounts with email and password only, without the
  TOTP authenticator.

  This is a deliberate security gap for an academic demo with fictitious data.
  It is off unless `config/runtime.exs` sets `:academic_demo_password_only` to
  `true`, which happens only when `ORIGEN_ACADEMIC_DEMO_PASSWORD_ONLY=true`.
  Patients and the magic link are not affected.
  """

  @doc "Returns true only when the academic demo password-only mode is explicitly on."
  @spec password_only?() :: boolean()
  def password_only?,
    do: Application.get_env(:origen, :academic_demo_password_only, false) == true
end
