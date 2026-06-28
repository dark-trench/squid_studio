defmodule SquidStudio.Web.StandaloneSmokeTest do
  use SquidStudio.ConnCase, async: true

  test "standalone studio smoke flow covers the command bar, edit, validate, and host handoff errors",
       %{
         conn: conn
       } do
    {:ok, view, _html} = live(conn, "/studio/workflows/daily_digest")

    assert_smoke_element(view, "#studio-context-bar", "load context bar")
    assert_smoke_element(view, "#studio-editor-command-bar", "load command bar")
    assert_smoke_element(view, "#studio-validate-draft-button", "load validate control")
    assert_smoke_element(view, "#studio-save-draft-button", "load save control")
    assert_smoke_element(view, "#studio-publish-draft-button", "load publish control")
    refute has_element?(view, "#studio-create-draft-button")
    refute has_element?(view, "#studio-delete-draft-button")

    assert_smoke_element(
      view,
      "#studio-catalog-entry-built_in-action_step",
      "load catalog action entry"
    )

    html =
      view
      |> element("#studio-validate-draft-button")
      |> render_click()

    assert html =~ "Valid draft"
    assert html =~ "Draft passes Squidie editor validation."

    html =
      view
      |> element("#studio-catalog-entry-built_in-action_step")
      |> render_click()

    assert html =~ "Action step added to the draft."
    assert html =~ ~s(id="studio-node-built_in-action_step-6")

    html =
      view
      |> element("#studio-save-draft-button")
      |> render_click()

    assert html =~ "Unsaved"
    assert html =~ "Host save support is not available."

    html =
      view
      |> element("#studio-publish-draft-button")
      |> render_click()

    assert html =~ "Publish handoff failed"
    assert html =~ "Host publish support is not available."
  end

  defp assert_smoke_element(view, selector, step) do
    assert has_element?(view, selector), """
    standalone smoke step failed: #{step}
    missing selector: #{selector}

    #{render(view)}
    """
  end
end
