defmodule Origen.PatientAccess.Email do
  @moduledoc """
  Builds transient magic link emails for passwordless patient authentication.
  """

  import Swoosh.Email

  @doc """
  Builds a Swoosh.Email containing the single-use magic link.
  The token is embedded in the link and delivered only to the target mailbox.
  """
  def magic_link(email, raw_token, opts \\ []) do
    config = Application.fetch_env!(:origen, :patient_access_email)
    origin = Keyword.get_lazy(opts, :origin, &OrigenWeb.Endpoint.url/0)
    link = "#{origin}/paciente/acceso/verificar?token=#{URI.encode_www_form(raw_token)}"

    new()
    |> to(email)
    |> from({"Origen", Keyword.fetch!(config, :from)})
    |> subject("Tu enlace de acceso a Origen")
    |> html_body("""
    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
      <h2>Acceso sin contraseña</h2>
      <p>Hacé clic en el siguiente enlace para ingresar a tu cuenta de paciente:</p>
      <p style="margin: 24px 0;">
        <a href="#{link}" target="_blank" rel="noopener noreferrer" style="background-color: #0A3847; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
          Ingresar a Origen
        </a>
      </p>
      <p style="color: #666; font-size: 13px;">
        Este enlace es de un solo uso y vence en 15 minutos. Si no solicitaste este acceso, podés ignorar este correo.
      </p>
    </div>
    """)
    # One bounded attempt: a timeout does not prove the provider rejected mail.
    |> put_private(:client_options,
      retry: false,
      receive_timeout: 5_000,
      connect_options: [timeout: 5_000]
    )
    |> text_body("""
    Acceso sin contraseña a Origen

    Ingresá al siguiente enlace para acceder a tu cuenta:
    #{link}

    Este enlace es de un solo uso y vence en 15 minutos.
    """)
  end
end
