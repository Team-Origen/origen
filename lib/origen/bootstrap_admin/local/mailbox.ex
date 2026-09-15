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
    store_opts = Keyword.take(opts, [:clock])

    if store.count(store_opts) > 0 do
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

      correlation_ref =
        "local-" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))

      with {:ok, email} <- InvitationEmail.build(transient, destination, origin, config),
           :ok <- reserve_mailbox(store, correlation_ref, [ttl_seconds: ttl] ++ store_opts) do
        case deliver_to_mailer(mailer, email) do
          :ok ->
            case replace_preview(email) do
              :ok ->
                {:ok, %{correlation_ref: correlation_ref}}

              {:error, :preview_failed} = error ->
                store.clear()
                error
            end

          {:error, :mailer_failed} = error ->
            store.clear()
            error
        end
      end
    end
  end

  defp deliver_to_mailer(mailer, email) do
    case mailer.deliver(email) do
      {:ok, _result} -> :ok
      _ -> {:error, :mailer_failed}
    end
  rescue
    _ -> {:error, :mailer_failed}
  catch
    _, _ -> {:error, :mailer_failed}
  end

  defp reserve_mailbox(store, correlation_ref, push_opts) do
    case store.push(%{id: correlation_ref}, push_opts) do
      :ok -> :ok
      {:error, :mailbox_full} -> {:error, :mailbox_retained}
      _ -> {:error, :store_failed}
    end
  end

  defp replace_preview(email) do
    storage = Swoosh.Adapters.Local.Storage.Memory
    storage.delete_all()
    storage.push(email)

    case storage.all() do
      [_delivered_email] -> :ok
      _ -> {:error, :preview_failed}
    end
  rescue
    _ -> {:error, :preview_failed}
  catch
    _, _ -> {:error, :preview_failed}
  end
end
