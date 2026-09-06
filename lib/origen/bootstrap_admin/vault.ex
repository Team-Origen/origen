defmodule Origen.BootstrapAdmin.Vault do
  @moduledoc "Cloak Vault boundary for runtime-configured tagged seed ciphers."
  use Cloak.Vault, otp_app: :origen
end
