defmodule Origen.ConsultationTypes.DatabaseCatalogTest do
  use Origen.DataCase, async: false

  alias Origen.{ConsultationTypes, Sessions}
  alias Origen.ConsultationTypes.DatabaseCatalog

  test "public snapshot uses persisted interval and active declared consultations without private settings" do
    %{rows: [[id]]} =
      Origen.Repo.query!("""
      INSERT INTO internal_accounts (role, state, password_hash, totp_secret, activated_at)
      VALUES ('professional', 'active', 'hash', decode('0102030405', 'hex'), NOW()) RETURNING id
      """)

    {:ok, %{session: principal}} = Sessions.create_session(id)
    assert {:ok, _} = ConsultationTypes.get_own_configuration(principal)

    attrs = %{
      name: "Consulta real",
      currency: "ARS",
      exact_price_ars: "21500.50",
      color: "#0A7C86",
      interval_count: 2
    }

    assert {:ok, active} = ConsultationTypes.create_type(principal, attrs)

    assert {:ok, inactive} =
             ConsultationTypes.create_type(principal, %{attrs | name: "Consulta retirada"})

    assert {:ok, _} = ConsultationTypes.deactivate_type(principal, inactive.id)

    assert {:ok, snapshot} =
             DatabaseCatalog.execute({:list, %{professional_reference: to_string(id)}})

    assert snapshot.source == :database
    assert snapshot.professional_reference == to_string(id)
    assert snapshot.agenda_interval_minutes == 30

    assert [
             %{
               id: active_id,
               name: "Consulta real",
               interval_count: 2,
               exact_price_ars: price,
               status: :active
             } = public
           ] = snapshot.consultation_types

    assert active_id == active.id
    assert Decimal.equal?(price, "21500.50")

    assert Enum.sort(Map.keys(public)) ==
             Enum.sort([:id, :name, :interval_count, :exact_price_ars, :status])

    assert {:ok, before} = ConsultationTypes.get_own_configuration(principal)

    for ref <- ["invalid", "1 OR 1=1", "0", "-1", nil] do
      assert {:error, :invalid_professional} =
               DatabaseCatalog.execute({:list, %{professional_reference: ref}})

      assert {:ok, ^before} = ConsultationTypes.get_own_configuration(principal)
    end

    assert {:error, :unavailable} =
             DatabaseCatalog.execute({:list, %{professional_reference: "9223372036854775807"}})
  end
end
