defmodule SquidStudio.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint SquidStudio.Test.Endpoint

      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Plug.Conn
      import SquidStudio.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
