defmodule SquidStudio.Web.HelpersTest do
  use ExUnit.Case, async: true

  alias SquidStudio.Web.Helpers

  setup do
    previous_routing = Process.get(:squid_studio_routing)

    on_exit(fn ->
      if is_nil(previous_routing) do
        Process.delete(:squid_studio_routing)
      else
        Process.put(:squid_studio_routing, previous_routing)
      end
    end)
  end

  test "builds prefixed paths without duplicate slashes" do
    assert Helpers.prefixed_path("/", "") == "/"
    assert Helpers.prefixed_path("", "/runs") == "/runs"
    assert Helpers.prefixed_path("/studio", "") == "/studio"
    assert Helpers.prefixed_path("/studio", "/runs") == "/studio/runs"
  end

  test "returns the root path when routing is intentionally disabled" do
    Process.put(:squid_studio_routing, :nowhere)

    assert Helpers.studio_path(["runs", "latest"], %{empty: "", missing: nil, status: "ready"}) ==
             "/"
  end

  test "raises when no studio routing context is available" do
    Process.delete(:squid_studio_routing)

    assert_raise RuntimeError, ~r/nothing stored in the :squid_studio_routing key/, fn ->
      Helpers.studio_path("/runs")
    end
  end
end
