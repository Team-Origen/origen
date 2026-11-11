defmodule Origen.Patients.PhoneVerificationEmail do
  @moduledoc """
  Builds transient emails containing the 6-digit phone verification code
  for local non-production delivery via Swoosh (PLN-15 / Issue #88 / #89).
  """

  import Swoosh.Email
  alias Origen.Patients.PhoneVerificationConfig

  @doc """
  Builds a Swoosh.Email containing the 6-digit phone verification code.
  Delivers to the patient's authenticated email via the local mailbox channel.
  """
  def challenge_code(recipient_email, phone, plain_code) do
    masked_phone = PhoneVerificationConfig.sanitize_phone(phone)
    ttl_minutes = div(PhoneVerificationConfig.code_ttl_seconds(), 60)

    new()
    |> to(recipient_email)
    |> from({"Origen", "noreply@example.test"})
    |> subject("Tu código de verificación telefónica de Origen")
    |> html_body("""
    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; color: #0A3847;">
      <h2 style="color: #0A3847; margin-bottom: 8px;">Verificación de Teléfono</h2>
      <p style="color: #35545A; font-size: 15px;">
        Recibimos una solicitud para verificar el número de teléfono <strong>#{masked_phone}</strong> en tu cuenta de paciente.
      </p>
      <div style="background-color: #F6F6F4; border: 1px solid #AFBAB4; border-radius: 8px; padding: 20px; text-align: center; margin: 24px 0;">
        <span style="font-size: 13px; color: #35545A; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">Tu código de seguridad</span>
        <div style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #0A3847; margin-top: 8px;">
          #{plain_code}
        </div>
      </div>
      <p style="color: #666; font-size: 13px;">
        Este código es de un solo uso y vence en #{ttl_minutes} minutos.
        Si no solicitaste esta verificación, podés desestimar este mensaje de forma segura.
      </p>
    </div>
    """)
    |> text_body("""
    Verificación de Teléfono - Origen

    Tu código de verificación para el número #{masked_phone} es:

    #{plain_code}

    Este código es de un solo uso y vence en #{ttl_minutes} minutos.
    """)
  end
end
