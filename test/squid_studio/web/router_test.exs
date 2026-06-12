defmodule SquidStudio.Web.RouterTest do
  use SquidStudio.ConnCase, async: true

  alias SquidStudio.Web.Assets

  test "mounts the embedded studio route", %{conn: conn} do
    conn = get(conn, "/studio")

    assert html_response(conn, 200) =~ "Squid Studio"
    assert html_response(conn, 200) =~ ~s(id="squid-studio-editor")
    assert html_response(conn, 200) =~ ~s(phx-hook="SquidStudioTheme")
    assert html_response(conn, 200) =~ "studio-theme-system"
    assert html_response(conn, 200) =~ ~s(id="squid-studio-flow")
    assert html_response(conn, 200) =~ ~s(phx-hook="SquidStudioFlow")
    assert html_response(conn, 200) =~ ~s(data-studio-theme="system")
    assert html_response(conn, 200) =~ ~s(data-studio-theme="light")
    assert html_response(conn, 200) =~ ~s(data-studio-theme="dark")
    assert html_response(conn, 200) =~ ~s(data-node-id="fetch_feed")
    assert html_response(conn, 200) =~ ~s(class="studio-edge")
    assert html_response(conn, 200) =~ "hero-squares-2x2"
    assert html_response(conn, 200) =~ "trigger :daily_digest"
    assert html_response(conn, 200) =~ "hero-clock"
  end

  test "serves hashed studio assets", %{conn: conn} do
    css = get(conn, "/studio/css-#{Assets.current_hash(:css)}")
    js = get(conn, "/studio/js-#{Assets.current_hash(:js)}")

    assert css.status == 200
    assert get_resp_header(css, "content-type") == ["text/css; charset=utf-8"]

    assert js.status == 200
    assert get_resp_header(js, "content-type") == ["application/javascript; charset=utf-8"]
  end

  test "serves the Squidie logo palette and theme controls in studio assets", %{conn: conn} do
    css = get(conn, "/studio/css-#{Assets.current_hash(:css)}")
    js = get(conn, "/studio/js-#{Assets.current_hash(:js)}")

    assert css.resp_body =~ "--studio-accent: #5edac9;"
    assert css.resp_body =~ "--studio-accent-strong: #75f9e0;"
    assert css.resp_body =~ "--studio-ink: #e9fffb;"
    assert css.resp_body =~ ".studio-theme-light"
    assert css.resp_body =~ ".studio-theme-dark"
    assert css.resp_body =~ ".studio-theme-system"
    assert css.resp_body =~ ".studio-theme-switcher"

    assert css.resp_body =~ "radial-gradient("
    assert css.resp_body =~ "var(--studio-canvas-dot) 1px"
    assert css.resp_body =~ "transparent 1.5px"
    assert css.resp_body =~ "background-size: 22px 22px;"

    assert js.resp_body =~ ~s(themeStorageKey = "squid-studio-theme")
    assert js.resp_body =~ "SquidStudioTheme"
    assert js.resp_body =~ "[data-studio-theme]"

    refute css.resp_body =~ "--studio-accent: #6d28d9;"

    refute css.resp_body =~
             "linear-gradient(90deg, rgba(117, 249, 224, 0.12) 1px, transparent 1px)"
  end

  test "rejects stale asset hashes", %{conn: conn} do
    conn = get(conn, "/studio/js-deadbeef")

    assert response(conn, 404) == "Not Found"
  end

  test "updates node position from the drag hook", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/studio")

    html =
      view
      |> render_hook("move_node", %{"id" => "fetch_feed", "x" => 120, "y" => 140})

    assert html =~ ~s(id="studio-node-fetch_feed")
    assert html =~ "left: 120px; top: 140px;"
    assert html =~ ~s(class="studio-edge")
  end

  test "sets the studio theme from the toolbar control", %{conn: conn} do
    {:ok, view, html} = live(conn, "/studio")

    assert html =~ "studio-theme-system"

    html =
      view
      |> element(~s(button[data-studio-theme="light"]))
      |> render_click()

    assert html =~ "studio-theme-light"
    refute html =~ "studio-theme-system"

    html =
      view
      |> element(~s(button[data-studio-theme="dark"]))
      |> render_click()

    assert html =~ "studio-theme-dark"
    refute html =~ "studio-theme-light"
  end

  test "centers the graph when the canvas reports its dimensions", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/studio")

    html =
      view
      |> render_hook("center_graph", %{"width" => 1200, "height" => 600})

    assert html =~ ~s(id="studio-node-fetch_feed")
    assert html =~ "left: 280px; top: 192px;"
    assert html =~ "M 200 230 C 280 230, 200 230, 280 230"
  end
end
