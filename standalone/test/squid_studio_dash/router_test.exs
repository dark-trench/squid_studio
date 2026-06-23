defmodule SquidStudioDash.RouterTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint SquidStudioDash.Endpoint

  test "renders the mounted workflow index at root" do
    conn = get(build_conn(), "/")

    assert html_response(conn, 200) =~ "Squidie Visual Editor"
    assert html_response(conn, 200) =~ "Daily RSS To Discord"
  end

  test "renders the mounted workflow index route" do
    conn = get(build_conn(), "/workflows")

    assert html_response(conn, 200) =~ "Squidie Visual Editor"
    assert html_response(conn, 200) =~ "Daily RSS To Discord"
  end

  test "renders the mounted workflow editor route" do
    conn = get(build_conn(), "/workflows/daily_digest")

    assert html_response(conn, 200) =~ "Squidie Visual Editor"
    assert html_response(conn, 200) =~ "Daily RSS To Discord"
  end

  test "validates a mounted workflow draft through the editor UI" do
    {:ok, view, _html} = live(build_conn(), "/workflows/daily_digest")

    assert has_element?(view, "#studio-validate-draft-button")

    html =
      view
      |> element("#studio-validate-draft-button")
      |> render_click()

    assert html =~ "Valid draft"
    assert html =~ "Draft passes Squidie editor validation."
  end
end
