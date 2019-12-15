# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
      use Pleroma.Tests.Helpers
      import Pleroma.Web.Router.Helpers

      # The default endpoint for testing
      @endpoint Pleroma.Web.Endpoint

      # Sets up OAuth access with specified scopes
      defp oauth_access(scopes, opts \\ %{}) do
        user =
          Map.get_lazy(opts, :user, fn ->
            Pleroma.Factory.insert(:user)
          end)

        token =
          Map.get_lazy(opts, :oauth_token, fn ->
            Pleroma.Factory.insert(:oauth_token, user: user, scopes: scopes)
          end)

        conn =
          build_conn()
          |> assign(:user, user)
          |> assign(:token, token)

        %{user: user, token: token, conn: conn}
      end
    end
  end

  setup tags do
    Cachex.clear(:user_cache)
    Cachex.clear(:object_cache)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Pleroma.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, {:shared, self()})
    end

    if tags[:needs_streamer] do
      start_supervised(Pleroma.Web.Streamer.supervisor())
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
