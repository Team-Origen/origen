defmodule Origen.PatientAccess.Mailer do
  @moduledoc "Delivery boundary for patient magic links; other email flows stay isolated."
  use Swoosh.Mailer, otp_app: :origen
end
