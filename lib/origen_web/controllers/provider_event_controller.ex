defmodule OrigenWeb.ProviderEventController do
  use OrigenWeb, :controller
  alias Origen.BootstrapAdmin
  alias OrigenWeb.ProviderEventReplay
  @safe_ref ~r/\A[A-Za-z0-9_-]{1,128}\z/
  def create(conn, params) do
    with {:ok, config} <- config(),
         {:ok, body} <- raw_body(conn),
         {:ok, timestamp} <- timestamp(conn, config),
         {:ok, secret} <- authenticate(conn, body, timestamp, config),
         {:ok, event, invitation, correlation} <- normalize(params, secret),
         identity = {event, invitation, correlation},
         :ok <- claim(identity),
         {:ok, _} <- revoke(config, invitation, identity),
         :ok <- ProviderEventReplay.complete(identity) do
      accepted(conn)
    else
      {:duplicate, _} ->
        accepted(conn)

      {:revocation_failed, identity} ->
        :ok = ProviderEventReplay.release(identity)
        send_resp(conn, 401, "")

      _ ->
        send_resp(conn, 401, "")
    end
  end

  defp config do
    case Application.get_env(:origen, :bootstrap_admin_provider_callback) do
      %{key_id: key, secret_resolver: resolver, clock: clock, replay_window_seconds: window} =
          config
      when is_binary(key) and is_function(resolver, 1) and is_function(clock, 0) and
             is_integer(window) and window in 1..900 ->
        {:ok, config}

      _ ->
        {:error, :invalid_configuration}
    end
  end

  defp raw_body(%Plug.Conn{assigns: %{raw_body: body}}) when is_binary(body) and body != "",
    do: {:ok, body}

  defp raw_body(_), do: {:error, :invalid_body}

  defp timestamp(conn, config) do
    with [value] <- get_req_header(conn, "x-origen-timestamp"),
         {timestamp, ""} <- Integer.parse(value),
         true <- abs(config.clock.() - timestamp) <= config.replay_window_seconds,
         do: {:ok, timestamp},
         else: (_ -> {:error, :invalid_timestamp})
  end

  defp authenticate(conn, body, timestamp, config) do
    with [key] <- get_req_header(conn, "x-origen-key-id"),
         true <- equal?(key, config.key_id),
         {:ok, secret} when is_binary(secret) and byte_size(secret) >= 32 <-
           config.secret_resolver.(key),
         [signature] <- get_req_header(conn, "x-origen-signature"),
         {:ok, supplied} <- Base.url_decode64(signature, padding: false),
         expected = :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{body}"),
         true <- equal?(supplied, expected),
         do: {:ok, secret},
         else: (_ -> {:error, :invalid_signature})
  end

  defp normalize(
         %{"type" => "delivery.failed", "event_id" => event, "correlation" => correlation},
         secret
       )
       when is_binary(event) and is_binary(correlation) do
    with true <- Regex.match?(@safe_ref, event),
         [id, signature] <- String.split(correlation, ".", parts: 2),
         {invitation, ""} when invitation > 0 <- Integer.parse(id),
         {:ok, supplied} <- Base.url_decode64(signature, padding: false),
         true <- equal?(supplied, :crypto.mac(:hmac, :sha256, secret, id)),
         do: {:ok, event, invitation, correlation},
         else: (_ -> {:error, :invalid_event})
  end

  defp normalize(_, _), do: {:error, :invalid_event}

  defp revoke(config, invitation, {event, _, _} = identity) do
    revoker = Map.get(config, :revoker, &BootstrapAdmin.revoke_delivery_failure/2)

    case revoker.(invitation, %{correlation_ref: event}) do
      {:ok, outcome} -> {:ok, outcome}
      _ -> {:revocation_failed, identity}
    end
  end

  defp claim(identity), do: ProviderEventReplay.claim(identity)

  defp equal?(left, right) when byte_size(left) == byte_size(right),
    do: Plug.Crypto.secure_compare(left, right)

  defp equal?(_, _), do: false
  defp accepted(conn), do: conn |> put_status(:accepted) |> json(%{outcome: "accepted"})
end
