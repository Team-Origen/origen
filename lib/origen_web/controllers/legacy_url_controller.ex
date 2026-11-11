defmodule OrigenWeb.LegacyUrlController do
  use OrigenWeb, :controller

  @destinations %{
    access: "/paciente/acceso",
    booking: "/paciente/turnos/reservar",
    phone: "/paciente/telefono/verificar",
    accounts: "/administrador/cuentas",
    settings: "/profesional/ajustes",
    profile: "/profesional/ajustes/perfil"
  }

  for {action, destination} <- @destinations do
    def unquote(action)(conn, _params) do
      query = if conn.query_string == "", do: "", else: "?" <> conn.query_string
      redirect(conn, to: unquote(destination) <> query)
    end
  end
end
