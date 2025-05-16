defmodule ContentSecurityPolicy.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build and test the CSP functionality.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest

      # Import the CSP module
      import ContentSecurityPolicy

      # The default endpoint for testing
      @endpoint Plug.Adapters.Test.Conn
    end
  end

  # Setup a basic connection for testing
  setup do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_private(:phoenix_endpoint, Plug.Adapters.Test.Conn)

    %{conn: conn}
  end
end
