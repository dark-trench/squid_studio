defmodule SquidStudio.Web.RouterTest do
  use SquidStudio.ConnCase, async: true

  alias SquidStudio.Web.Assets

  test "mounts the embedded workflows page", %{conn: conn} do
    conn = get(conn, "/studio")

    html = html_response(conn, 200)

    assert html =~ "Squid Studio"
    assert html =~ "Squidie Visual Editor"
    assert html =~ ~s(id="squid-studio-workflows")
    assert html =~ ~r/<h3>\s*Workflows\s*<\/h3>/
    assert html =~ "Daily RSS To Discord"
    assert html =~ ~s(id="workflow-resource-toolbar")
    assert html =~ ~s(id="workflow-new-draft-link")
    assert html =~ ~s(class="studio-workflows-header-inner")
    assert html =~ ~s(class="studio-wordmark")

    assert html =~ ~r/class="studio-workflows-header-actions"[\s\S]*class="studio-theme-switcher"/

    refute html =~
             ~r/class="studio-workflows-header-actions"[\s\S]{0,500}id="workflow-new-draft-link"/

    assert html =~ ~r/id="workflow-search-form"[\s\S]*id="workflow-new-draft-link"/

    assert html =~ "Approval inbox"
    assert html =~ "Dynamic work"
    assert html =~ "Draft specs"
    assert html =~ ~s(class="studio-workflow-tabs")
    assert html =~ ~s(class="studio-workflow-tab)
    assert html =~ ~s(class="studio-workflow-card is-clickable-row")
    assert html =~ ~s(class="studio-workflow-row-icon")
    assert html =~ ~s(class="studio-workflow-row-meta")
    assert html =~ ~s(class="studio-workflow-run-details")
    assert html =~ ~s(class="studio-workflows-panel-actions")
    refute html =~ ~s(class="studio-count-pill")
    assert html =~ "Run inspection"
    assert html =~ "Get Started"
    assert html =~ "Healthy drain"
    assert html =~ "Last run delivered 12 feed items"
    assert html =~ "Host execution"
    assert html =~ "Approval gate"
    assert html =~ ~s(href="/studio/workflows/daily_digest")
    refute html =~ "Squidie host"
    refute html =~ "Workflows Visual Builder"
    refute html =~ "Squidie starters"
    refute html =~ "Workflow queue"
    refute html =~ "Host workflows"
    refute html =~ "Live</span>"
  end

  test "filters workflows by operational status", %{conn: conn} do
    {:ok, view, html} = live(conn, "/studio")

    assert html =~ "Daily RSS To Discord"
    assert html =~ "Approval Saga With Compensation"
    assert html =~ "Dynamic Subscription Fanout"

    html =
      view
      |> element(~s(.studio-workflow-tab[phx-value-status="approval"]))
      |> render_click()

    assert html =~ "Approval Saga With Compensation"
    assert html =~ "Waiting for approval"
    refute html =~ "Daily RSS To Discord"
    refute html =~ "Dynamic Subscription Fanout"

    html =
      view
      |> element(~s(.studio-workflow-tab[phx-value-status="all"]))
      |> render_click()

    assert html =~ "Daily RSS To Discord"
    assert html =~ "Dynamic Subscription Fanout"
  end

  test "searches workflow inventory and clears empty status views", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/studio")

    html =
      view
      |> element(~s(.studio-workflow-tab[phx-value-status="draft"]))
      |> render_click()

    assert html =~ "Runtime Authored Spec"
    refute html =~ "Daily RSS To Discord"

    html =
      view
      |> form("#workflow-search-form", workflow_filter: %{q: "bedrock"})
      |> render_change()

    assert html =~ "No workflows match this view."
    refute html =~ "Bedrock Lease Drain"

    html =
      view
      |> element(~s(.studio-workflow-tab[phx-value-status="all"]))
      |> render_click()

    assert html =~ "Bedrock Lease Drain"
    assert html =~ "Bedrock lease runner"
  end

  test "switches workflow templates and theme on the management page", %{conn: conn} do
    {:ok, view, html} = live(conn, "/studio")

    assert html =~ "studio-theme-system"
    assert html =~ "Purchase or release flows"

    html =
      view
      |> element(~s(button[phx-value-id="bedrock_lease"]))
      |> render_click()

    assert html =~ "Backend-owned delivery"
    assert html =~ "Host execution"

    html =
      view
      |> element(~s(button[data-studio-theme="dark"]))
      |> render_click()

    assert html =~ "studio-theme-dark"
    refute html =~ "studio-theme-system"
  end

  test "mounts the embedded studio editor route", %{conn: conn} do
    conn = get(conn, "/studio/workflows/daily_digest")

    html = html_response(conn, 200)

    assert html =~ "Squid Studio"
    assert html =~ "Squidie Visual Editor"
    assert html =~ ~s(id="squid-studio-editor")

    assert html =~
             ~s(<a href="/studio" data-phx-link="redirect" data-phx-link-state="push" class="studio-wordmark">)

    assert html =~ ~r|class="studio-breadcrumb"[\s\S]*href="/studio"[\s\S]*>Workflows</a>|
    assert html =~ ~s(phx-hook="SquidStudioTheme")
    assert html =~ "studio-theme-system"
    assert html =~ ~s(id="squid-studio-flow")
    assert html =~ ~s(phx-hook="SquidStudioFlow")
    assert html =~ ~s(data-studio-theme="system")
    assert html =~ ~s(data-studio-theme="light")
    assert html =~ ~s(data-studio-theme="dark")
    assert html =~ ~s(data-node-id="fetch_feed")
    assert html =~ ~s(class="studio-edge")
    assert html =~ "Workflow drafts"
    assert html =~ "trigger :daily_digest"
    assert html =~ "hero-clock"
    assert html =~ "Draft spec"
    assert html =~ "Host persistence"
    assert html =~ "Publish version"
    refute html =~ "Squidie host"
    refute html =~ "Workflows Visual Builder"
    refute html =~ "Live</span>"
  end

  test "uses a full-width editor topbar above the workspace panels", %{conn: conn} do
    html =
      conn
      |> get("/studio/workflows/daily_digest")
      |> html_response(200)

    assert html =~ ~s(<header class="studio-topbar">)
    assert html =~ ~s(<div class="studio-workspace">)
    assert html =~ ~s(<aside class="studio-sidebar">)
    assert html =~ ~s(<section class="studio-canvas-column">)
    assert html =~ ~s(<aside class="studio-properties">)
    refute html =~ ~s(class="studio-toolbar")
    refute html =~ "Review</span>"
    refute html =~ "Validate</span>"
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
    assert css.resp_body =~ "--studio-topbar-height: 56px;"
    assert css.resp_body =~ ".studio-topbar .studio-metric span"
    assert css.resp_body =~ "grid-template-columns: repeat(2, minmax(78px, auto));"
    assert css.resp_body =~ "--studio-workflows-content-width: 1280px;"
    assert css.resp_body =~ "width: min(100%, var(--studio-workflows-content-width));"
    assert css.resp_body =~ "justify-self: center;"
    assert css.resp_body =~ ".studio-workflows-header-inner"
    assert css.resp_body =~ ".studio-workflows-grid"
    assert css.resp_body =~ "grid-template-columns: minmax(0, 1fr) 320px;"
    assert css.resp_body =~ ".studio-workflow-tabs"
    assert css.resp_body =~ ".studio-workflow-tab"
    assert css.resp_body =~ ".studio-workflow-row-icon"
    assert css.resp_body =~ ".studio-workflow-run-details"
    assert css.resp_body =~ ".studio-workflow-row-meta"
    assert css.resp_body =~ "grid-template-columns: 34px minmax(0, 1fr) auto;"
    assert css.resp_body =~ "padding: 11px 14px;"
    assert css.resp_body =~ "@media (max-width: 1040px)"
    assert css.resp_body =~ "grid-template-columns: repeat(3, minmax(0, 1fr));"
    assert css.resp_body =~ "grid-template-rows: auto minmax(0, 1fr);"
    assert css.resp_body =~ "grid-template-columns: minmax(0, 1fr) auto;"
    assert css.resp_body =~ "flex-wrap: nowrap;"
    assert css.resp_body =~ ".studio-workflows-panel-actions form"
    assert css.resp_body =~ "flex: 1 1 220px;"
    assert css.resp_body =~ "@media (max-width: 520px)"
    assert css.resp_body =~ "border-radius: 6px;"
    assert css.resp_body =~ ".studio-template-preview .studio-button"
    assert css.resp_body =~ ".studio-breadcrumb a"
    assert css.resp_body =~ "a.studio-wordmark:hover strong"
    assert css.resp_body =~ ".studio-wordmark"
    assert css.resp_body =~ "width: fit-content;"
    refute css.resp_body =~ ".studio-workflows-sidepanels"

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
    {:ok, view, _html} = live(conn, "/studio/workflows/daily_digest")

    html =
      view
      |> render_hook("move_node", %{"id" => "fetch_feed", "x" => 120, "y" => 140})

    assert html =~ ~s(id="studio-node-fetch_feed")
    assert html =~ "left: 120px; top: 140px;"
    assert html =~ ~s(class="studio-edge")
  end

  test "sets the studio theme from the topbar control", %{conn: conn} do
    {:ok, view, html} = live(conn, "/studio/workflows/daily_digest")

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

  test "surfaces host draft persistence failures without losing editor state", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/studio/workflows/daily_digest")

    html =
      view
      |> element(~s(button[phx-click="save_draft"]))
      |> render_click()

    assert html =~ "Unsaved"
    assert html =~ "Draft was kept in the editor"
    assert html =~ "persistence_not_configured"
    assert html =~ ~s(id="studio-node-fetch_feed")

    html =
      view
      |> element(~s(button[phx-click="publish_draft"]))
      |> render_click()

    assert html =~ "Publish handoff failed"
    assert html =~ "publish_not_configured"
    assert html =~ ~s(id="studio-node-fetch_feed")
  end

  test "uses host callbacks for draft selection, save, and publish", %{conn: conn} do
    {:ok, view, html} = live(conn, "/host-studio/workflows/invoice_review")

    assert html =~ "Invoice Review"
    assert html =~ "Carrier Onboarding"

    html =
      view
      |> element(~s(button[phx-value-id="carrier_onboarding"]))
      |> render_click()

    assert html =~ "carrier_onboarding"
    assert html =~ "Host persistence owns save, delete, and publish callbacks."

    html =
      view
      |> element(~s(button[phx-click="save_draft"]))
      |> render_click()

    assert html =~ "Saved"
    assert html =~ "Host persistence accepted the draft spec."

    html =
      view
      |> element(~s(button[phx-click="publish_draft"]))
      |> render_click()

    assert html =~ "Published"
    assert html =~ "Host published a runnable Squidie workflow version."
  end

  test "renders host connector catalog metadata without credential values", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/host-studio/workflows/invoice_review")

    assert html =~ "Messaging"
    assert html =~ "Post message"
    assert html =~ "Send an approved Slack message"
    assert html =~ "Slack bot token"
    assert html =~ "Code"
    assert html =~ "Create issue"
    assert html =~ "production only"
    assert html =~ ~s(data-catalog-action-key="post_message")
    assert html =~ ~s(draggable="true")
    assert html =~ ~s(data-catalog-action-key="create_issue")
    assert html =~ ~s(draggable="false")
    refute html =~ "xoxb-secret"
  end

  test "catalog node insertion rejects disabled or unauthorized entries", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    html =
      view
      |> render_hook("add_catalog_node", %{"action_key" => "create_issue"})

    refute html =~ ~s(id="studio-node-github-create_issue")
    assert html =~ "Connector unavailable: production only"

    html =
      view
      |> render_hook("add_catalog_node", %{"action_key" => "post_message"})

    assert html =~ ~s(id="studio-node-slack-post_message")
    assert html =~ "Post message"
  end

  test "centers the graph when the canvas reports its dimensions", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/studio/workflows/daily_digest")

    html =
      view
      |> render_hook("center_graph", %{"width" => 1200, "height" => 600})

    assert html =~ ~s(id="studio-node-fetch_feed")
    assert html =~ "left: 280px; top: 192px;"
    assert html =~ "M 200 230 C 280 230, 200 230, 280 230"
  end
end
