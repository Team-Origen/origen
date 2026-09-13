defmodule Origen.BootstrapAdmin.Local.Mailbox do
  @moduledoc """
  Coordinates bounded in-memory delivery and retention for the local development profile.
  """

  alias Origen.BootstrapAdmin.Local.{Destination, InvitationEmail, MailboxStore, Origin}

  @spec deliver(map(), keyword()) ::
          {:ok, %{correlation_ref: String.t()}} | {:error, atom()}
  def deliver(transient, opts \\ []) do
    ttl = Keyword.get(opts, :ttl_seconds, 900)
    store = Keyword.get(opts, :store, MailboxStore)
    mailer = Keyword.get(opts, :mailer, Origen.Mailer)

    if store.count() > 0 do
      {:error, :mailbox_retained}
    else
      config =
        Keyword.get(opts, :config) ||
          Application.get_env(:origen, :bootstrap_admin_local_config, %{})

      destination =
        Keyword.get(opts, :destination) ||
          Destination.parse(config[:destination] || "admin@example.test")
          |> case do
            {:ok, d} -> d
            _ -> %Destination{address: "admin@example.test"}
          end

      origin =
        Keyword.get(opts, :origin) ||
          Origin.validate(
            config[:activation_origin] || "https://127.0.0.1:4443/admin/activate",
            config[:endpoint] || %{scheme: :https, ip: {127, 0, 0, 1}, port: 4443, http: false}
          )
          |> case do
            {:ok, o} -> o
            _ -> %Origin{uri: URI.parse("https://127.0.0.1:4443/admin/activate")}
          end

      with {:ok, email} <- InvitationEmail.build(transient, destination, origin, config),
           {:ok, delivery_result} <- deliver_to_mailer(mailer, email),
           :ok <- store_in_mailbox(store, email, delivery_result, ttl, opts) do
        correlation_ref =
          "local-" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))

        {:ok, %{correlation_ref: correlation_ref}}
      end
    end
  end

  defp deliver_to_mailer(mailer, email) do
    case mailer.deliver(email) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :mailer_failed}
    end
  rescue
    _ -> {:error, :mailer_failed}
  catch
    _, _ -> {:error, :mailer_failed}
  end

  defp store_in_mailbox(store, email, delivery_result, ttl, opts) do
    msg_id =
      case delivery_result do
        %{id: id} -> id
        _ -> Map.get(email.headers, "Message-ID")
      end

    push_opts = [ttl_seconds: ttl] ++ Keyword.take(opts, [:clock])

    # Also forward to Swoosh.Adapters.Local.Storage.Memory if it is running and different from store
    # so that /dev/mailbox preview can see it
    if store != Swoosh.Adapters.Local.Storage.Memory do
      try do
        Swoosh.Adapters.Local.Storage.Memory.push(email)
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end
    end

    case store.push(%{id: msg_id, email: email}, push_opts) do
      :ok -> :ok
      {:error, :mailbox_full} -> {:error, :mailbox_retained}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :store_failed}
    end
  end
end
