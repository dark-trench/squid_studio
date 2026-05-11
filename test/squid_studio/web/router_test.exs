defmodule SquidStudio.Web.RouterTest do
  use SquidStudio.ConnCase, async: true

  alias SquidStudio.Web.Assets

  test "mounts the embedded studio route", %{conn: conn} do
    conn = get(conn, "/studio")

    assert html_response(conn, 200) =~ "Squid Studio"
    assert html_response(conn, 200) =~ ~s(id="squid-studio-flow")
    assert html_response(conn, 200) =~ ~s(phx-hook="SquidStudioFlow")
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
