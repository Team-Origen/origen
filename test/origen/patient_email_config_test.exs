defmodule Origen.PatientEmailConfigTest do
  use ExUnit.Case, async: false

  @vars ~w(RESEND_API_KEY ORIGEN_PATIENT_EMAIL_FROM PHX_HOST RENDER_EXTERNAL_HOSTNAME DATABASE_URL SECRET_KEY_BASE)

  setup do
    previous = Map.new(@vars, &{&1, System.get_env(&1)})

    System.put_env(%{
      "DATABASE_URL" => "ecto://test:test@localhost/origen_test",
      "SECRET_KEY_BASE" => String.duplicate("k", 64),
      "RESEND_API_KEY" => "test-key",
      "ORIGEN_PATIENT_EMAIL_FROM" => "acceso@mail.origen-demo.org",
      "PHX_HOST" => "origen-demo.onrender.com"
    })

    System.delete_env("RENDER_EXTERNAL_HOSTNAME")

    on_exit(fn ->
      Enum.each(previous, fn {key, value} ->
        if value, do: System.put_env(key, value), else: System.delete_env(key)
      end)
    end)

    :ok
  end

  defp read_config do
    Config.Reader.read!("config/runtime.exs", env: :prod)
  end

  test "configures only patient delivery using Resend and a verified sender" do
    config = read_config()[:origen]
    assert config[Origen.PatientAccess.Mailer][:adapter] == Swoosh.Adapters.Resend
    assert config[Origen.PatientAccess.Mailer][:api_key] == "test-key"
    assert config[:patient_access_email][:from] == "acceso@mail.origen-demo.org"
    refute Keyword.has_key?(config, Origen.Mailer)
  end

  test "requires credentials and sender without echoing values" do
    for key <- ~w(RESEND_API_KEY ORIGEN_PATIENT_EMAIL_FROM) do
      original = System.fetch_env!(key)
      System.put_env(key, " ")
      assert_raise RuntimeError, "#{key} is required for patient email delivery", &read_config/0
      System.put_env(key, original)
    end
  end

  test "requires an approved public hostname, allowing Render's hostname fallback" do
    System.delete_env("PHX_HOST")
    assert_raise RuntimeError, ~r/public hostname/, &read_config/0
    System.put_env("RENDER_EXTERNAL_HOSTNAME", "origen.onrender.com")
    assert read_config()[:origen][Origen.PatientAccess.Mailer][:adapter] == Swoosh.Adapters.Resend
  end

  test "rejects local, placeholder, URL-shaped hosts and example senders" do
    for host <- [
          "localhost",
          "127.0.0.1",
          "example.com",
          "https://origen-demo.onrender.com",
          "origen-demo.onrender.com/path",
          "origen-demo.onrender.com:4000"
        ] do
      System.put_env("PHX_HOST", host)
      assert_raise RuntimeError, ~r/public hostname/, &read_config/0
    end

    System.put_env("PHX_HOST", "origen-demo.onrender.com")

    for sender <- ["noreply@example.test", "invalid", "x@example.com", "a\nb@origen.org"] do
      System.put_env("ORIGEN_PATIENT_EMAIL_FROM", sender)
      assert_raise RuntimeError, ~r/valid non-placeholder sender/, &read_config/0
    end
  end
end
