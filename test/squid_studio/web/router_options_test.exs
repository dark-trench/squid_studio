defmodule SquidStudio.Web.RouterOptionsTest do
  use ExUnit.Case, async: true

  alias SquidStudio.Web.Router

  test "rejects unsupported live transport values" do
    assert_raise ArgumentError, ~r/invalid :transport/, fn ->
      Router.__options__("/studio", transport: "ftp")
    end
  end

  test "accepts custom resolver modules" do
    assert {_session_name, session_opts, [as: :studio]} =
             Router.__options__("/studio", resolver: SquidStudio.Web.Resolver)

    assert Keyword.fetch!(session_opts, :root_layout) == {SquidStudio.Web.Layouts, :root}
  end
end
