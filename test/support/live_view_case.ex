defmodule OrigenWeb.LiveViewCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a LiveView connection.

  It provides helpers for mounting LiveViews, rendering
  components, and simulating user interactions like
  typing and clicking.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint OrigenWeb.Endpoint

      use OrigenWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import OrigenWeb.LiveViewCase
    end
  end

  setup tags do
    unless tags[:skip_db] do
      Origen.DataCase.setup_sandbox(tags)
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
