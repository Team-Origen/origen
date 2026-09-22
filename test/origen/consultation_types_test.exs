defmodule Origen.ConsultationTypesTest do
  use Origen.DataCase, async: false

  alias Origen.ConsultationTypes
  alias Origen.Repo
  alias Origen.Sessions

  describe "get_own_configuration/1" do
    test "establishes the default configuration for a persisted professional session" do
      principal = professional_principal!()

      assert {:ok, configuration} = ConsultationTypes.get_own_configuration(principal)
      assert configuration == %{agenda_interval_minutes: 30, consultation_types: []}

      assert {:ok, ^configuration} = ConsultationTypes.get_own_configuration(principal)
    end

    test "returns only consultation types owned by the resolved account" do
      first_account_id = insert_active_account!(:professional)
      second_account_id = insert_active_account!(:professional)
      first_principal = principal_for!(first_account_id)
      second_principal = principal_for!(second_account_id)

      insert_agenda_settings!(first_account_id, 15)
      insert_agenda_settings!(second_account_id, 45)

      insert_consultation_type!(first_account_id,
        id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
        name: "General consultation"
      )

      insert_consultation_type!(second_account_id,
        id: "018f4a5b-0d62-7a44-8e32-2f608bfcb002",
        name: "Private consultation"
      )

      assert {:ok,
              %{
                agenda_interval_minutes: 15,
                consultation_types: [
                  %{
                    id: "018f4a5b-0d62-7a44-8e32-2f608bfcb001",
                    name: "General consultation",
                    exact_price_ars: price,
                    color: "#0A7C86",
                    interval_count: 2,
                    status: :active,
                    inactive_duration_minutes: nil
                  }
                ]
              }} = ConsultationTypes.get_own_configuration(first_principal)

      assert Decimal.equal?(price, Decimal.new("18000.00"))

      assert {:ok,
              %{
                agenda_interval_minutes: 45,
                consultation_types: [%{name: "Private consultation"}]
              }} = ConsultationTypes.get_own_configuration(second_principal)
    end

    test "reloads account role and state instead of trusting principal claims" do
      professional_id = insert_active_account!(:professional)
      principal = principal_for!(professional_id)

      claimed_role = %{principal | role: :administrator}
      assert {:ok, _configuration} = ConsultationTypes.get_own_configuration(claimed_role)

      Repo.query!(
        """
        UPDATE internal_accounts
        SET state = 'pending_activation', password_hash = NULL, totp_secret = NULL,
            activated_at = NULL
        WHERE id = $1
        """,
        [professional_id]
      )

      assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(principal)
    end

    test "fails closed for other roles and caller-created or altered account bindings" do
      for role <- [:administrator, :secretary] do
        principal = role |> insert_active_account!() |> principal_for!()
        assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(principal)
      end

      professional_id = insert_active_account!(:professional)
      other_professional_id = insert_active_account!(:professional)
      principal = principal_for!(professional_id)

      assert {:error, :unauthorized} =
               ConsultationTypes.get_own_configuration(%{
                 account_id: professional_id,
                 role: :professional
               })

      assert {:error, :unauthorized} =
               ConsultationTypes.get_own_configuration(%{
                 principal
                 | account_id: other_professional_id,
                   role: :professional
               })

      :ok = Sessions.terminate_all_sessions(professional_id)
      assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(principal)
    end

    test "fails closed for missing accounts and malformed or missing principals" do
      account_id = insert_active_account!(:professional)
      principal = principal_for!(account_id)
      Repo.query!("DELETE FROM internal_accounts WHERE id = $1", [account_id])

      assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(principal)

      for malformed <- [nil, %{}, %{session_id: "1", account_id: 1}, "principal"] do
        assert {:error, :unauthorized} = ConsultationTypes.get_own_configuration(malformed)
      end
    end
  end

  describe "create_type/2" do
    test "creates an active type with a server UUID and authoritative readback" do
      principal = professional_principal!()

      assert {:ok, created} =
               ConsultationTypes.create_type(
                 principal,
                 valid_type_attrs(%{name: "  Follow  up  "})
               )

      assert %{
               id: id,
               name: "Follow  up",
               exact_price_ars: price,
               color: "#0A7C86",
               interval_count: 2,
               status: :active,
               inactive_duration_minutes: nil
             } = created

      assert {:ok, ^id} = Ecto.UUID.cast(id)
      assert Decimal.equal?(price, Decimal.new("18000.50"))

      assert {:ok, %{consultation_types: [^created]}} =
               ConsultationTypes.get_own_configuration(principal)
    end

    test "allows duplicate names and exact nonnegative prices without a commercial maximum" do
      principal = professional_principal!()

      assert {:ok, first} =
               ConsultationTypes.create_type(
                 principal,
                 valid_type_attrs(%{exact_price_ars: Decimal.new("0.00")})
               )

      assert {:ok, second} =
               ConsultationTypes.create_type(
                 principal,
                 valid_type_attrs(%{exact_price_ars: "999999999999999999999999999999.99"})
               )

      assert first.name == second.name
      assert first.id != second.id
      assert Decimal.equal?(first.exact_price_ars, Decimal.new("0.00"))

      assert Decimal.equal?(
               second.exact_price_ars,
               Decimal.new("999999999999999999999999999999.99")
             )

      assert {:ok, %{consultation_types: types}} =
               ConsultationTypes.get_own_configuration(principal)

      assert Enum.map(types, & &1.id) |> Enum.sort() == Enum.sort([first.id, second.id])
    end

    test "accepts a name containing exactly 32 graphemes regardless of codepoint count" do
      principal = professional_principal!()
      name = String.duplicate("é", 32)

      assert String.length(name) == 32

      assert {:ok, %{name: ^name}} =
               ConsultationTypes.create_type(principal, valid_type_attrs(%{name: name}))
    end

    test "rejects invalid names, prices, and colors without changing the catalog" do
      principal = professional_principal!()

      invalid_cases = [
        {%{name: "   "}, %{name: :required}},
        {%{name: String.duplicate("á", 33)}, %{name: :too_long}},
        {%{exact_price_ars: "-0.01"}, %{exact_price_ars: :nonnegative}},
        {%{exact_price_ars: "1.001"}, %{exact_price_ars: :scale}},
        {%{exact_price_ars: "not-a-price"}, %{exact_price_ars: :invalid}},
        {%{color: "#0a7c86"}, %{color: :invalid}},
        {%{color: "0A7C86"}, %{color: :invalid}}
      ]

      for {override, expected_errors} <- invalid_cases do
        assert {:error, {:validation, errors}} =
                 ConsultationTypes.create_type(principal, valid_type_attrs(override))

        assert Map.take(errors, Map.keys(expected_errors)) == expected_errors

        assert {:ok, %{consultation_types: []}} =
                 ConsultationTypes.get_own_configuration(principal)
      end
    end

    test "parses interval counts and enforces the default interval-dependent maximum" do
      principal = professional_principal!()

      assert {:ok, %{interval_count: 8}} =
               ConsultationTypes.create_type(principal, valid_type_attrs(%{interval_count: "8"}))

      for invalid_count <- [0, "9", "2.0", nil] do
        assert {:error, {:validation, %{interval_count: :invalid}}} =
                 ConsultationTypes.create_type(
                   principal,
                   valid_type_attrs(%{interval_count: invalid_count})
                 )
      end

      assert {:ok, %{consultation_types: [_only_valid_type]}} =
               ConsultationTypes.get_own_configuration(principal)
    end

    test "uses the locked persisted Agenda Interval when validating the count" do
      account_id = insert_active_account!(:professional)
      principal = principal_for!(account_id)
      insert_agenda_settings!(account_id, 60)

      assert {:ok, %{interval_count: 4}} =
               ConsultationTypes.create_type(principal, valid_type_attrs(%{interval_count: 4}))

      assert {:error, {:validation, %{interval_count: :invalid}}} =
               ConsultationTypes.create_type(principal, valid_type_attrs(%{interval_count: 5}))

      assert {:ok, %{agenda_interval_minutes: 60, consultation_types: [_only_valid_type]}} =
               ConsultationTypes.get_own_configuration(principal)
    end

    test "rejects browser-supplied identity, ownership, and lifecycle fields" do
      principal = professional_principal!()

      protected_fields = [
        %{id: Ecto.UUID.generate()},
        %{owner_account_id: 123},
        %{"owner_account_id" => 123},
        %{status: :inactive},
        %{inactive_duration_minutes: 30}
      ]

      for protected <- protected_fields do
        assert {:error, {:validation, %{base: :protected_fields}}} =
                 ConsultationTypes.create_type(
                   principal,
                   Map.merge(valid_type_attrs(), protected)
                 )
      end

      assert {:ok, %{consultation_types: []}} =
               ConsultationTypes.get_own_configuration(principal)
    end

    test "fails closed for invalid principals without creating owner configuration" do
      professional_id = insert_active_account!(:professional)
      administrator = :administrator |> insert_active_account!() |> principal_for!()

      for invalid_principal <- [
            nil,
            %{account_id: professional_id, role: :professional},
            administrator
          ] do
        assert {:error, :unauthorized} =
                 ConsultationTypes.create_type(invalid_principal, valid_type_attrs())
      end

      assert Repo.query!("SELECT count(*) FROM agenda_settings").rows == [[0]]
      assert Repo.query!("SELECT count(*) FROM consultation_types").rows == [[0]]
    end
  end

  describe "update_type/3" do
    test "updates an active owned type and preserves its immutable state" do
      principal = professional_principal!()
      original = create_type!(principal)

      assert {:ok, updated} =
               ConsultationTypes.update_type(
                 principal,
                 original.id,
                 valid_type_attrs(%{
                   name: "  Follow  up  ",
                   exact_price_ars: Decimal.new("25000.25"),
                   color: "#4DB5E6",
                   interval_count: "3"
                 })
               )

      assert updated == %{
               id: original.id,
               name: "Follow  up",
               exact_price_ars: Decimal.new("25000.25"),
               color: "#4DB5E6",
               interval_count: 3,
               status: :active,
               inactive_duration_minutes: nil
             }

      assert {:ok, %{consultation_types: [^updated]}} =
               ConsultationTypes.get_own_configuration(principal)
    end

    test "aggregates validation errors and leaves the prior type unchanged" do
      principal = professional_principal!()
      original = create_type!(principal)

      assert {:error,
              {:validation,
               %{
                 name: :required,
                 exact_price_ars: :nonnegative,
                 color: :invalid,
                 interval_count: :invalid
               }}} =
               ConsultationTypes.update_type(principal, original.id, %{
                 name: " ",
                 exact_price_ars: "-0.01",
                 color: "#ffffff",
                 interval_count: 0
               })

      assert {:ok, %{consultation_types: [^original]}} =
               ConsultationTypes.get_own_configuration(principal)
    end

    test "validates count against the current locked Agenda Interval" do
      account_id = insert_active_account!(:professional)
      principal = principal_for!(account_id)
      insert_agenda_settings!(account_id, 60)
      original = create_type!(principal, %{interval_count: 4})

      assert {:error, {:validation, %{interval_count: :invalid}}} =
               ConsultationTypes.update_type(
                 principal,
                 original.id,
                 valid_type_attrs(%{interval_count: 5})
               )

      assert {:ok, %{agenda_interval_minutes: 60, consultation_types: [^original]}} =
               ConsultationTypes.get_own_configuration(principal)
    end

    test "rejects protected fields and preserves identity and lifecycle state" do
      principal = professional_principal!()
      original = create_type!(principal)

      for protected <- [
            %{id: Ecto.UUID.generate()},
            %{owner_account_id: 123},
            %{"owner_account_id" => 123},
            %{status: :inactive},
            %{inactive_duration_minutes: 30}
          ] do
        assert {:error, {:validation, %{base: :protected_fields}}} =
                 ConsultationTypes.update_type(
                   principal,
                   original.id,
                   Map.merge(valid_type_attrs(%{name: "Changed"}), protected)
                 )

        assert {:ok, %{consultation_types: [^original]}} =
                 ConsultationTypes.get_own_configuration(principal)
      end
    end

    test "treats malformed, missing, inactive, and cross-owner targets identically" do
      owner_principal = professional_principal!()
      other_principal = professional_principal!()
      active = create_type!(owner_principal)
      inactive = create_type!(owner_principal, %{name: "Inactive consultation"})

      Repo.query!(
        """
        UPDATE consultation_types
        SET status = 'inactive', inactive_duration_minutes = 60
        WHERE id = $1
        """,
        [Ecto.UUID.dump!(inactive.id)]
      )

      targets = [
        {owner_principal, "not-a-uuid"},
        {owner_principal, String.upcase(active.id)},
        {owner_principal, Ecto.UUID.generate()},
        {owner_principal, inactive.id},
        {other_principal, active.id}
      ]

      for {principal, target_id} <- targets do
        assert {:error, :not_found} =
                 ConsultationTypes.update_type(
                   principal,
                   target_id,
                   valid_type_attrs(%{name: "Must not change"})
                 )
      end

      assert {:ok, %{consultation_types: owner_types}} =
               ConsultationTypes.get_own_configuration(owner_principal)

      assert Enum.find(owner_types, &(&1.id == active.id)) == active

      assert Enum.find(owner_types, &(&1.id == inactive.id)) == %{
               inactive
               | status: :inactive,
                 inactive_duration_minutes: 60
             }

      assert {:ok, %{consultation_types: []}} =
               ConsultationTypes.get_own_configuration(other_principal)
    end

    test "fails closed for invalid principals and leaves the target unchanged" do
      principal = professional_principal!()
      original = create_type!(principal)
      administrator = :administrator |> insert_active_account!() |> principal_for!()

      for invalid_principal <- [
            nil,
            %{account_id: principal.account_id, role: :professional},
            administrator
          ] do
        assert {:error, :unauthorized} =
                 ConsultationTypes.update_type(
                   invalid_principal,
                   original.id,
                   valid_type_attrs(%{name: "Must not change"})
                 )
      end

      assert {:ok, %{consultation_types: [^original]}} =
               ConsultationTypes.get_own_configuration(principal)
    end
  end

  describe "deactivate_type/2" do
    test "deactivates without deletion and snapshots the current duration" do
      account_id = insert_active_account!(:professional)
      principal = principal_for!(account_id)
      insert_agenda_settings!(account_id, 15)

      original =
        create_type!(principal, %{
          name: "Preserved consultation",
          exact_price_ars: Decimal.new("32000.75"),
          color: "#4DB5E6",
          interval_count: 3
        })

      assert {:ok, inactive} = ConsultationTypes.deactivate_type(principal, original.id)

      assert inactive == %{
               original
               | status: :inactive,
                 inactive_duration_minutes: 45
             }

      assert {:ok,
              %{
                agenda_interval_minutes: 15,
                consultation_types: [^inactive]
              }} = ConsultationTypes.get_own_configuration(principal)
    end

    test "keeps the historical inactive duration after a later Agenda Interval change" do
      principal = professional_principal!()
      original = create_type!(principal, %{interval_count: 4})

      assert {:ok, %{inactive_duration_minutes: 120} = inactive} =
               ConsultationTypes.deactivate_type(principal, original.id)

      Repo.query!(
        "UPDATE agenda_settings SET interval_minutes = 60 WHERE owner_account_id = $1",
        [principal.account_id]
      )

      assert {:ok,
              %{
                agenda_interval_minutes: 60,
                consultation_types: [^inactive]
              }} = ConsultationTypes.get_own_configuration(principal)
    end

    test "treats repeated, malformed, missing, and cross-owner targets identically" do
      owner_principal = professional_principal!()
      other_principal = professional_principal!()
      owner_type = create_type!(owner_principal)
      foreign_type = create_type!(other_principal, %{name: "Foreign consultation"})

      assert {:ok, inactive} =
               ConsultationTypes.deactivate_type(owner_principal, owner_type.id)

      targets = [
        {owner_principal, owner_type.id},
        {owner_principal, "not-a-uuid"},
        {owner_principal, String.upcase(owner_type.id)},
        {owner_principal, Ecto.UUID.generate()},
        {owner_principal, foreign_type.id}
      ]

      for {principal, target_id} <- targets do
        assert {:error, :not_found} =
                 ConsultationTypes.deactivate_type(principal, target_id)

        assert {:ok, %{consultation_types: [^inactive]}} =
                 ConsultationTypes.get_own_configuration(owner_principal)

        assert {:ok, %{consultation_types: [^foreign_type]}} =
                 ConsultationTypes.get_own_configuration(other_principal)
      end
    end

    test "fails closed for invalid principals and leaves the target active" do
      principal = professional_principal!()
      original = create_type!(principal)
      administrator = :administrator |> insert_active_account!() |> principal_for!()

      for invalid_principal <- [
            nil,
            %{account_id: principal.account_id, role: :professional},
            administrator
          ] do
        assert {:error, :unauthorized} =
                 ConsultationTypes.deactivate_type(invalid_principal, original.id)
      end

      assert {:ok, %{consultation_types: [^original]}} =
               ConsultationTypes.get_own_configuration(principal)
    end
  end

  describe "reactivate_type/2" do
    test "reactivates a compatible inactive type and preserves its data and count" do
      principal = professional_principal!()

      original =
        create_type!(principal, %{
          name: "Preserved consultation",
          exact_price_ars: Decimal.new("32000.75"),
          color: "#4DB5E6",
          interval_count: 3
        })

      inactive = deactivate_type!(principal, original.id)

      Repo.query!(
        "UPDATE agenda_settings SET interval_minutes = 60 WHERE owner_account_id = $1",
        [principal.account_id]
      )

      assert {:ok, reactivated} =
               ConsultationTypes.reactivate_type(principal, inactive.id)

      assert reactivated == original

      assert {:ok,
              %{
                agenda_interval_minutes: 60,
                consultation_types: [^reactivated]
              }} = ConsultationTypes.get_own_configuration(principal)
    end

    test "accepts an exact prospective duration of 240 minutes" do
      principal = professional_principal!()
      original = create_type!(principal, %{interval_count: 4})
      inactive = deactivate_type!(principal, original.id)

      Repo.query!(
        "UPDATE agenda_settings SET interval_minutes = 60 WHERE owner_account_id = $1",
        [principal.account_id]
      )

      assert {:ok, ^original} = ConsultationTypes.reactivate_type(principal, inactive.id)
    end

    test "rejects an incompatible duration without adapting the preserved count or history" do
      principal = professional_principal!()
      original = create_type!(principal, %{name: "Long consultation", interval_count: 5})
      inactive = deactivate_type!(principal, original.id)

      Repo.query!(
        "UPDATE agenda_settings SET interval_minutes = 60 WHERE owner_account_id = $1",
        [principal.account_id]
      )

      assert {:error,
              {:incompatible,
               %{
                 name: "Long consultation",
                 prospective_duration_minutes: 300
               }}} = ConsultationTypes.reactivate_type(principal, inactive.id)

      assert {:ok,
              %{
                agenda_interval_minutes: 60,
                consultation_types: [^inactive]
              }} = ConsultationTypes.get_own_configuration(principal)

      assert inactive.interval_count == 5
      assert inactive.inactive_duration_minutes == 150
    end

    test "treats active, malformed, missing, and cross-owner targets identically" do
      owner_principal = professional_principal!()
      other_principal = professional_principal!()
      active = create_type!(owner_principal)

      foreign_inactive =
        other_principal
        |> create_type!(%{name: "Foreign consultation"})
        |> then(&deactivate_type!(other_principal, &1.id))

      targets = [
        active.id,
        "not-a-uuid",
        String.upcase(active.id),
        Ecto.UUID.generate(),
        foreign_inactive.id
      ]

      for target_id <- targets do
        assert {:error, :not_found} =
                 ConsultationTypes.reactivate_type(owner_principal, target_id)

        assert {:ok, %{consultation_types: [^active]}} =
                 ConsultationTypes.get_own_configuration(owner_principal)

        assert {:ok, %{consultation_types: [^foreign_inactive]}} =
                 ConsultationTypes.get_own_configuration(other_principal)
      end
    end

    test "fails closed for invalid principals and leaves the target inactive" do
      principal = professional_principal!()
      inactive = principal |> create_type!() |> then(&deactivate_type!(principal, &1.id))
      administrator = :administrator |> insert_active_account!() |> principal_for!()

      for invalid_principal <- [
            nil,
            %{account_id: principal.account_id, role: :professional},
            administrator
          ] do
        assert {:error, :unauthorized} =
                 ConsultationTypes.reactivate_type(invalid_principal, inactive.id)
      end

      assert {:ok, %{consultation_types: [^inactive]}} =
               ConsultationTypes.get_own_configuration(principal)
    end
  end

  describe "apply_agenda_interval/2" do
    test "accepts interval boundaries and canonical integer strings" do
      principal = professional_principal!()

      for interval <- [5, "240", "30"] do
        expected = if is_binary(interval), do: String.to_integer(interval), else: interval

        assert {:ok, %{agenda_interval_minutes: ^expected, consultation_types: []}} =
                 ConsultationTypes.apply_agenda_interval(principal, interval)
      end

      for invalid <- [0, 7, 245, "05", "+30", " 30", "30.0", nil] do
        assert {:error, {:validation, %{agenda_interval_minutes: :invalid}}} =
                 ConsultationTypes.apply_agenda_interval(principal, invalid)

        assert {:ok, %{agenda_interval_minutes: 30, consultation_types: []}} =
                 ConsultationTypes.get_own_configuration(principal)
      end
    end

    test "applies a compatible interval and preserves all type identity and history" do
      principal = professional_principal!()
      other_principal = professional_principal!()
      active = create_type!(principal, %{name: "Exact boundary", interval_count: 4})
      inactive = create_type!(principal, %{name: "Historical", interval_count: 2})
      inactive = deactivate_type!(principal, inactive.id)
      foreign = create_type!(other_principal, %{name: "Foreign consultation"})

      assert {:ok, applied} = ConsultationTypes.apply_agenda_interval(principal, 60)

      assert applied == %{
               agenda_interval_minutes: 60,
               consultation_types: [active, inactive]
             }

      assert active.interval_count * applied.agenda_interval_minutes == 240
      assert inactive.inactive_duration_minutes == 60
      assert {:ok, ^applied} = ConsultationTypes.get_own_configuration(principal)

      assert {:ok, %{agenda_interval_minutes: 30, consultation_types: [^foreign]}} =
               ConsultationTypes.get_own_configuration(other_principal)

      assert {:ok, ^applied} = ConsultationTypes.apply_agenda_interval(principal, "60")
    end

    test "returns every blocker deterministically and rejects without mutation" do
      principal = professional_principal!()
      compatible = create_type!(principal, %{name: "Compatible", interval_count: 4})
      first_blocker = create_type!(principal, %{name: "Long follow-up", interval_count: 5})
      second_blocker = create_type!(principal, %{name: "Extended intake", interval_count: 7})
      inactive = create_type!(principal, %{name: "Inactive history", interval_count: 8})
      inactive = deactivate_type!(principal, inactive.id)

      assert {:ok, before_configuration} =
               ConsultationTypes.get_own_configuration(principal)

      expected_blockers =
        before_configuration.consultation_types
        |> Enum.filter(&(&1.id in [first_blocker.id, second_blocker.id]))
        |> Enum.map(fn type ->
          %{
            id: type.id,
            name: type.name,
            interval_count: type.interval_count,
            prospective_duration_minutes: type.interval_count * 60
          }
        end)

      assert {:error,
              {:incompatible,
               %{
                 maximum_interval_count: 4,
                 blockers: ^expected_blockers
               }}} = ConsultationTypes.apply_agenda_interval(principal, 60)

      assert length(expected_blockers) == 2
      assert {:ok, ^before_configuration} = ConsultationTypes.get_own_configuration(principal)

      assert Enum.find(before_configuration.consultation_types, &(&1.id == compatible.id)) ==
               compatible

      assert Enum.find(before_configuration.consultation_types, &(&1.id == inactive.id)) ==
               inactive
    end

    test "fails closed for invalid principals without changing the interval" do
      principal = professional_principal!()
      administrator = :administrator |> insert_active_account!() |> principal_for!()

      for invalid_principal <- [
            nil,
            %{account_id: principal.account_id, role: :professional},
            administrator
          ] do
        assert {:error, :unauthorized} =
                 ConsultationTypes.apply_agenda_interval(invalid_principal, 60)
      end

      assert {:ok, %{agenda_interval_minutes: 30}} =
               ConsultationTypes.get_own_configuration(principal)
    end
  end

  defp professional_principal! do
    :professional
    |> insert_active_account!()
    |> principal_for!()
  end

  defp principal_for!(account_id) do
    {:ok, %{session: principal}} = Sessions.create_session(account_id)
    principal
  end

  defp insert_active_account!(role) do
    %{rows: [[account_id]]} =
      Repo.query!(
        """
        INSERT INTO internal_accounts
          (role, state, password_hash, totp_secret, activated_at)
        VALUES
          ($1, 'active', 'argon2_hash_dummy', decode('0102030405', 'hex'), NOW())
        RETURNING id
        """,
        [Atom.to_string(role)]
      )

    account_id
  end

  defp insert_agenda_settings!(account_id, interval_minutes) do
    Repo.query!(
      """
      INSERT INTO agenda_settings (owner_account_id, interval_minutes)
      VALUES ($1, $2)
      """,
      [account_id, interval_minutes]
    )
  end

  defp insert_consultation_type!(account_id, attrs) do
    Repo.query!(
      """
      INSERT INTO consultation_types
        (id, owner_account_id, name, exact_price_ars, color, interval_count, status)
      VALUES ($1, $2, $3, $4, $5, $6, 'active')
      """,
      [
        attrs |> Keyword.fetch!(:id) |> Ecto.UUID.dump!(),
        account_id,
        Keyword.fetch!(attrs, :name),
        Decimal.new("18000.00"),
        "#0A7C86",
        2
      ]
    )
  end

  defp valid_type_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        name: "General consultation",
        exact_price_ars: "18000.50",
        color: "#0A7C86",
        interval_count: 2
      },
      overrides
    )
  end

  defp create_type!(principal, overrides \\ %{}) do
    {:ok, consultation_type} =
      ConsultationTypes.create_type(principal, valid_type_attrs(overrides))

    consultation_type
  end

  defp deactivate_type!(principal, consultation_type_id) do
    {:ok, consultation_type} =
      ConsultationTypes.deactivate_type(principal, consultation_type_id)

    consultation_type
  end
end
