defmodule Origen.BootstrapAdmin.OperatorDocumentationTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @runbook Path.join(@root, "docs/deployment/FIRST_ADMIN_BOOTSTRAP.md")
  @handling Path.join(@root, "docs/security/ACTIVATION_DATA_HANDLING.md")
  @matrix Path.join(@root, "docs/security/AUTHORIZATION_MATRIX.md")
  @context Path.join(@root, "docs/CONTEXT.md")

  test "operator examples use protected approval input and reference-only output" do
    runbook = File.read!(@runbook)

    assert runbook =~ "--approval-input-ref"
    assert runbook =~ "Reference-only result"
    refute runbook =~ "ORIGEN_BOOTSTRAP_ADMIN_EMAIL="
    refute runbook =~ "--email"
    refute runbook =~ "--verifier-key"
  end

  test "runbook keeps production disabled and requires fresh approval after failure" do
    runbook = File.read!(@runbook)

    assert runbook =~ "**prepared/not executed**"
    assert runbook =~ "fresh approval"
    assert runbook =~ "fresh invitation"
    assert runbook =~ "Do not retry or resubmit the failed invitation"
    refute runbook =~ ~r/(enable|enabled|set).*production/i
  end

  test "acceptance worksheet solicits references and decisions, never sensitive values" do
    runbook = File.read!(@runbook)

    worksheet =
      runbook |> String.split("## Sanitized real-staging acceptance worksheet") |> List.last()

    for required <- [
          "Approver evidence reference",
          "Provider-control evidence reference",
          "Synthetic-canary result reference",
          "Failure-drill result reference",
          "Happy-path result reference",
          "Disablement result reference",
          "Reviewer sign-off reference",
          "Rollback decision",
          "Started-at timestamp",
          "Completed-at timestamp"
        ] do
      assert worksheet =~ required
    end

    for forbidden <- [
          "Recipient address:",
          "Token:",
          "Full URL:",
          "Message body:",
          "Credential:",
          "Assertion body:"
        ] do
      refute worksheet =~ forbidden
    end
  end

  test "security and authority docs state provider and callback rollout blockers" do
    combined = Enum.map_join([@handling, @matrix, @context], "\n", &File.read!/1)

    for required <- [
          "node-local",
          "no time-based pruning",
          "ingress affinity or shared replay",
          "provider credentials",
          "distinct authorized confirmer",
          "prepared/not executed"
        ] do
      assert combined =~ required
    end
  end

  test "current authorization additions remain draft while approved history is preserved" do
    matrix = File.read!(@matrix)

    [current_status | _] =
      Regex.run(~r/^> \*\*Estado:\*\* (.+)$/m, matrix, capture: :all_but_first)

    current_status = String.trim(current_status)

    assert current_status == "Draft — pending independent review"
    assert matrix =~ "`0.5-draft` ni `0.6-draft`"
    assert matrix =~ "| `0.4` | 2026-08-24 | Aprobada — validada por el equipo |"
    refute current_status =~ ~r/aprobada|approved/i
  end

  test "acceptance status remains open, blocked, and not completed" do
    runbook = File.read!(@runbook)
    context = File.read!(@context)

    assert runbook =~ "Staging acceptance is **prepared/not executed**"
    assert runbook =~ "Issue #3 must remain open"
    assert context =~ "Staging remains blocked"
    assert runbook =~ "CI or an authorized human owns this evidence"
    assert runbook =~ "a skipped local command is not a pass"

    refute runbook =~ ~r/(approval|deployment|email|activation|CI) (is|was|has been) completed/i
  end

  test "the runbook preserves OpenSpec history instead of overwriting it" do
    runbook = File.read!(@runbook)

    assert runbook =~ "Never overwrite, delete, or rewrite archived OpenSpec history"
    refute runbook =~ ~r/(overwrite|replace|delete) (the )?(historical|archived) OpenSpec/i
  end
end
