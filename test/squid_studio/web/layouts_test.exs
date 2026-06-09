defmodule SquidStudio.Web.LayoutsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  test "renders app content and flash messages" do
    html =
      render_component(&SquidStudio.LayoutTestComponent.render/1,
        flash: %{"info" => "Saved", "error" => "Failed"}
      )

    assert html =~ "Editor"
    assert html =~ "Saved"
    assert html =~ "Failed"
    assert html =~ "border-red-200"
    assert html =~ "border-emerald-200"
  end
end
