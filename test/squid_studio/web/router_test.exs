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
    assert html =~ ~s(id="studio-surface-switcher")
    assert html =~ "Spec view"
    assert html =~ ~s(data-studio-theme="system")
    assert html =~ ~s(data-studio-theme="light")
    assert html =~ ~s(data-studio-theme="dark")
    assert html =~ ~s(data-node-id="fetch_feed")
    assert html =~ "studio-edge"
    assert html =~ "Workflow drafts"
    assert html =~ "trigger :daily_digest"
    assert html =~ "hero-clock"
    assert html =~ "Draft spec"
    assert html =~ "Host persistence"
    assert html =~ ~s(id="studio-catalog-search-input")
    assert html =~ ~s(aria-label="Search node catalog")
    assert html =~ "Publish version"
    assert html =~ "Validate draft"
    assert html =~ ~s(id="squid-studio-flow")
    assert html =~ ~s(tabindex="0")
    assert html =~ ~s(aria-label="Workflow canvas")
    assert html =~ ~s(class="studio-draft-item is-active")
    assert html =~ ~s(aria-pressed="true")
    refute html =~ "Squidie host"
    refute html =~ "Workflows Visual Builder"
    refute html =~ "Live</span>"
  end

  test "keeps the selected workflow, draft, and canvas graph aligned", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/studio/workflows/approval_saga")

    assert html =~ "Approval Saga With Compensation"
    assert html =~ ~s(id="studio-workflow-approval_saga")
    assert html =~ ~s(id="studio-node-start_request")
    assert html =~ ~s(id="studio-node-manager_vote")

    assert html =~
             ~r/id="studio-workflow-approval_saga"[\s\S]*class="studio-workflow-item is-active"/

    assert html =~
             ~r/id="studio-draft-item-approval_saga"[\s\S]*class="studio-draft-item is-active"/

    refute html =~ ~s(id="studio-node-daily_digest")
  end

  test "switches workflows from the editor sidebar", %{conn: conn} do
    {:ok, view, html} = live(conn, "/studio/workflows/daily_digest")

    assert html =~ "Daily RSS To Discord"
    assert html =~ ~s(id="studio-node-daily_digest")

    html =
      view
      |> element("#studio-workflow-approval_saga")
      |> render_click()

    assert html =~ "Approval Saga With Compensation"
    assert html =~ ~s(id="studio-node-start_request")
    refute html =~ ~s(id="studio-node-daily_digest")
  end

  test "renders host draft graph positions and labels from editor specs", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/host-studio/workflows/invoice_review")

    assert html =~ ~s(id="studio-node-invoice_added")
    assert html =~ "Invoice added"
    assert html =~ "Review invoice draft"
    assert html =~ "left: 24px; top: 96px;"
    assert html =~ "left: 332px; top: 168px;"
    refute html =~ "trigger :invoice_added"
    refute html =~ "step :review_invoice"
  end

  test "switches from the visual editor to a read-only spec view", %{conn: conn} do
    {:ok, view, html} = live(conn, "/host-studio/workflows/invoice_review")

    assert html =~ ~s(id="squid-studio-flow")
    refute html =~ ~s(id="studio-spec-view")

    html =
      view
      |> element(~s(button[phx-value-surface="spec"]))
      |> render_click()

    assert html =~ ~s(id="studio-spec-view")
    assert html =~ "&quot;workflow&quot;: &quot;invoice_review&quot;"
    assert html =~ "&quot;definition_version&quot;: &quot;draft&quot;"
    assert html =~ "&quot;steps&quot;: ["
    refute html =~ "placeholder-value"

    html =
      view
      |> element(~s(button[phx-value-id="carrier_onboarding"]))
      |> render_click()

    assert html =~ "&quot;workflow&quot;: &quot;carrier_onboarding&quot;"
    assert html =~ "Validation issues"
    assert html =~ "duplicate step name: review_invoice"
    assert html =~ "steps.2.name"
    assert html =~ "transition outcome must be ok or error"
    assert html =~ "transitions.0.on"
  end

  test "keeps the spec view in sync with draft edits", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    html =
      view
      |> element(~s(button[phx-value-surface="spec"]))
      |> render_click()

    assert html =~ "&quot;workflow&quot;: &quot;invoice_review&quot;"
    refute html =~ "&quot;action_key&quot;: &quot;post_message&quot;"

    html =
      view
      |> render_hook("add_catalog_node", %{"provider" => "slack", "action_key" => "post_message"})

    assert html =~ "&quot;name&quot;: &quot;slack-post_message-2&quot;"
    assert html =~ "&quot;action&quot;: &quot;post_message&quot;"
    assert html =~ "&quot;provider&quot;: &quot;slack&quot;"
    refute html =~ "&quot;nodes&quot;: ["
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
    assert html =~ ~s(phx-click="validate_draft")
    refute html =~ ~s(class="studio-toolbar")
    refute html =~ "Review</span>"
  end

  test "validates draft specs from the editor toolbar", %{conn: conn} do
    {:ok, view, html} = live(conn, "/host-studio/workflows/invoice_review")

    assert html =~ ~s(phx-click="validate_draft")
    assert html =~ "Not validated"

    html =
      view
      |> element(~s(button[phx-click="validate_draft"]))
      |> render_click()

    assert html =~ "Valid draft"
    assert html =~ "Draft passes Squidie editor validation."
    refute html =~ "Validation issues"

    html =
      view
      |> element(~s(button[phx-value-id="carrier_onboarding"]))
      |> render_click()

    assert html =~ "Validation issues"
    assert html =~ "duplicate step name: review_invoice"
    assert html =~ "transition outcome must be ok or error"

    html =
      view
      |> element(~s(button[phx-click="validate_draft"]))
      |> render_click()

    assert html =~ "Validation issues"
    assert html =~ "2 validation issues found."
    assert html =~ ~s(id="studio-node-review_invoice")
    assert html =~ ~s(class="studio-node-validation-badge")
    assert html =~ ~s(class="studio-edge studio-edge-invalid")
  end

  test "rejects hidden catalog actions during draft validation and publish", %{conn: conn} do
    {:ok, view, html} = live(conn, "/host-studio/workflows/invoice_review")

    assert html =~ "Invoice Review"

    html =
      view
      |> element(~s(button[phx-value-id="restricted_issue_flow"]))
      |> render_click()

    assert html =~ "Restricted Issue Flow"
    assert html =~ "Open restricted issue"

    html =
      view
      |> element(~s(button[phx-click="validate_draft"]))
      |> render_click()

    assert html =~ "Validation issues"
    assert html =~ "action create_issue is not available for this user"
    assert html =~ "steps.1.action"
    assert html =~ ~s(data-validation-anchor-id="open_issue")
    assert html =~ ~s(class="studio-node is-selected is-invalid")

    html =
      view
      |> element(~s(button[phx-click="publish_draft"]))
      |> render_click()

    assert html =~ "Publish blocked until validation issues are resolved."
    refute html =~ "Host published a runnable Squidie workflow version."
    assert html =~ "action create_issue is not available for this user"
  end

  test "focuses invalid graph elements from validation output", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    invalid_html =
      view
      |> element(~s(button[phx-value-id="carrier_onboarding"]))
      |> render_click()

    assert invalid_html =~ ~s(data-validation-anchor-kind="node")
    assert invalid_html =~ ~s(data-validation-anchor-id="review_invoice")
    assert invalid_html =~ ~s(data-validation-anchor-kind="edge")
    assert invalid_html =~ ~s(data-validation-anchor-id="invoice_added:pending:review_invoice")

    edge_html =
      view
      |> element(~s(button[data-validation-anchor-id="invoice_added:pending:review_invoice"]))
      |> render_click()

    assert edge_html =~ ~s(class="studio-edge studio-edge-invalid is-selected")
    assert edge_html =~ "Selected edge"
    assert edge_html =~ "invoice_added"
    assert edge_html =~ "review_invoice"

    node_html =
      view
      |> element(~s(button[data-validation-anchor-id="review_invoice"]))
      |> render_click()

    assert node_html =~ ~s(id="studio-node-review_invoice")
    assert node_html =~ ~s(class="studio-node is-selected is-invalid")
    assert node_html =~ "review_invoice"
  end

  test "clears stale validation markers after draft edits", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    invalid_html =
      view
      |> element(~s(button[phx-value-id="carrier_onboarding"]))
      |> render_click()

    assert invalid_html =~ "Validation issues"
    assert invalid_html =~ ~s(class="studio-node-validation-badge")
    assert invalid_html =~ ~s(class="studio-edge studio-edge-invalid")

    updated_html =
      view
      |> render_hook("add_catalog_node", %{"provider" => "slack", "action_key" => "post_message"})

    assert updated_html =~ "Not validated"
    assert updated_html =~ "Run validation before publishing or starting a workflow."
    refute updated_html =~ ~s(class="studio-node-validation-badge")
    refute updated_html =~ ~s(class="studio-edge studio-edge-invalid")
    refute updated_html =~ ~s(data-validation-anchor-id="review_invoice")
    refute updated_html =~ ~s(data-validation-anchor-id="invoice_added:pending:review_invoice")
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
    assert css.resp_body =~ "--studio-sidebar-width: clamp(220px, 22vw, 260px);"
    assert css.resp_body =~ "--studio-properties-width: clamp(250px, 26vw, 300px);"
    assert css.resp_body =~ ".studio-theme-switcher"
    assert css.resp_body =~ "--studio-topbar-height: 56px;"
    assert css.resp_body =~ ".studio-topbar .studio-metric span"

    assert css.resp_body =~
             "grid-template-columns: minmax(180px, 0.7fr) minmax(0, 1.1fr) auto minmax(280px, 1.3fr);"

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
    assert css.resp_body =~ ".studio-button span"
    assert css.resp_body =~ "row-gap: 8px;"
    assert css.resp_body =~ ".hero-arrow-path"
    assert css.resp_body =~ ".hero-check-circle"
    assert css.resp_body =~ ~r/\.studio-canvas-column\s*\{[^}]*row-gap: 12px;/s
    assert css.resp_body =~ "@media (max-width: 1280px)"
    assert css.resp_body =~ "@media (max-width: 1040px)"
    assert css.resp_body =~ "grid-template-columns: repeat(3, minmax(0, 1fr));"
    assert css.resp_body =~ "grid-template-rows: auto minmax(0, 1fr);"
    assert css.resp_body =~ "grid-template-rows: auto auto minmax(0, 1fr);"
    assert css.resp_body =~ "grid-template-columns: minmax(0, 1fr) auto;"
    assert css.resp_body =~ "flex-wrap: nowrap;"
    assert css.resp_body =~ ".studio-workflows-panel-actions form"
    assert css.resp_body =~ "flex: 1 1 220px;"
    assert css.resp_body =~ "overflow-wrap: anywhere;"
    assert css.resp_body =~ "@media (max-width: 520px)"
    assert css.resp_body =~ "border-radius: 6px;"
    assert css.resp_body =~ ".studio-template-preview .studio-button"
    assert css.resp_body =~ ".studio-breadcrumb a"
    assert css.resp_body =~ "a.studio-wordmark:hover strong"
    assert css.resp_body =~ ".studio-wordmark"
    assert css.resp_body =~ "width: fit-content;"
    assert css.resp_body =~ ".studio-edge-invalid"
    assert css.resp_body =~ "stroke-dasharray: 10 6;"
    refute css.resp_body =~ ".studio-workflows-sidepanels"

    assert css.resp_body =~ "radial-gradient("
    assert css.resp_body =~ "var(--studio-canvas-dot) 1px"
    assert css.resp_body =~ "transparent 1.5px"
    assert css.resp_body =~ "background-size: 22px 22px;"

    assert js.resp_body =~ ~s(themeStorageKey = "squid-studio-theme")
    assert js.resp_body =~ "SquidStudioTheme"
    assert js.resp_body =~ "[data-studio-theme]"
    assert js.resp_body =~ "drop_catalog_node"
    assert js.resp_body =~ "dataTransfer"

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
    assert html =~ "studio-edge"
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
    assert html =~ "Host save support is not available."
    assert html =~ ~s(id="studio-node-fetch_feed")
    refute html =~ "persistence_not_configured"

    html =
      view
      |> element(~s(button[phx-click="publish_draft"]))
      |> render_click()

    assert html =~ "Publish handoff failed"
    assert html =~ "Host publish support is not available."
    assert html =~ ~s(id="studio-node-fetch_feed")
    refute html =~ "publish_not_configured"
  end

  test "renders safe empty and error states for failing host resolvers", %{conn: conn} do
    workflows_html =
      conn
      |> get("/error-state-studio")
      |> html_response(200)

    assert workflows_html =~ "Workflow inventory unavailable."
    assert workflows_html =~ "Host workflow data is temporarily unavailable."
    refute workflows_html =~ "secret=abc123"
    refute workflows_html =~ "resolver exploded"

    {:ok, _view, editor_html} = live(conn, "/error-state-studio/workflows/missing")

    assert editor_html =~ "Workflow unavailable."
    assert editor_html =~ "Host workflow data is temporarily unavailable."
    assert editor_html =~ "Host did not authorize draft access."
    assert editor_html =~ "Host has not enabled connector actions."
    refute editor_html =~ "secret=abc123"
    refute editor_html =~ "resolver exploded"
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

  test "enforces read-only mode across editor mutations", %{conn: conn} do
    {:ok, view, html} = live(conn, "/read-only-studio/workflows/invoice_review")

    assert html =~ "Read-only"
    assert html =~ ~s(id="squid-studio-flow")
    assert html =~ ~s(data-read-only="true")

    assert html =~ ~s(id="studio-publish-draft-button")
    assert html =~ ~s(id="studio-save-draft-button")
    assert html =~ ~s(id="studio-validate-draft-button")

    assert html =~ ~r/id="studio-publish-draft-button"[^>]*disabled/
    assert html =~ ~r/id="studio-save-draft-button"[^>]*disabled/

    assert html =~ ~s(data-catalog-action-key="post_message")
    assert html =~ ~s(disabled)

    html =
      view
      |> render_hook("move_node", %{"id" => "review_invoice", "x" => 320, "y" => 160})

    assert html =~ ~s(id="studio-node-review_invoice")
    assert html =~ "left: 332px; top: 168px;"
    assert html =~ "Read-only access cannot change drafts."

    html =
      view
      |> render_hook("add_catalog_node", %{"provider" => "slack", "action_key" => "post_message"})

    refute html =~ ~s(id="studio-node-slack-post_message-2")
    assert html =~ "Read-only access cannot change drafts."

    html =
      view
      |> render_click("save_draft", %{})

    assert html =~ "Read-only access cannot change drafts."
    assert html =~ "Draft spec"

    html =
      view
      |> render_click("publish_draft", %{})

    assert html =~ "Read-only access cannot change drafts."
    assert html =~ "Draft spec"
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
    refute html =~ "placeholder-value"
  end

  test "catalog node insertion rejects disabled or unauthorized entries", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    html =
      view
      |> render_hook("add_catalog_node", %{"action_key" => "create_issue"})

    refute html =~ ~s(id="studio-node-github-create_issue-)
    assert html =~ "Connector unavailable: production only"

    html =
      view
      |> render_hook("add_catalog_node", %{"action_key" => "post_message"})

    assert html =~ ~s(id="studio-node-slack-post_message-2")
    assert html =~ "Post message"
  end

  test "catalog node insertion generates stable unique ids for repeated actions", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    first_html =
      view
      |> render_hook("add_catalog_node", %{"action_key" => "post_message"})

    assert first_html =~ ~s(id="studio-node-slack-post_message-2")

    second_html =
      view
      |> render_hook("add_catalog_node", %{"action_key" => "post_message"})

    assert second_html =~ ~s(id="studio-node-slack-post_message-2")
    assert second_html =~ ~s(id="studio-node-slack-post_message-3")
  end

  test "renders structured properties for the selected action node", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    html =
      view
      |> render_hook("add_catalog_node", %{"action_key" => "post_message"})

    assert html =~ "Post message"
    assert html =~ "Action key"
    assert html =~ "post_message"
    assert html =~ "Provider"
    assert html =~ "slack"
    assert html =~ "Credential requirements"
    assert html =~ "Slack bot token"
    assert html =~ "Input contract"
    assert html =~ "channel"
    assert html =~ "text"
    assert html =~ "Output contract"
    assert html =~ "message_id"

    html =
      view
      |> element("#studio-node-review_invoice")
      |> render_click()

    assert html =~ "Review invoice draft"
    assert html =~ "Step name"
    assert html =~ "review_invoice"
    refute html =~ "<p class=\"studio-kicker\">Credential requirements</p>"
    refute html =~ "<span>Action key</span>"
  end

  test "edits step name and label from the properties panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    selected_html =
      view
      |> element("#studio-node-review_invoice")
      |> render_click()

    assert selected_html =~ ~s(id="studio-step-properties-form")

    updated_html =
      view
      |> form("#studio-step-properties-form",
        step_properties: %{
          name: "approve_invoice",
          label: "Approve invoice draft"
        }
      )
      |> render_change()

    assert updated_html =~ ~s(id="studio-node-approve_invoice")
    assert updated_html =~ "Approve invoice draft"
    refute updated_html =~ ~s(id="studio-node-review_invoice")

    spec_html =
      view
      |> element(~s(button[phx-value-surface="spec"]))
      |> render_click()

    assert spec_html =~ "&quot;name&quot;: &quot;approve_invoice&quot;"
    assert spec_html =~ "&quot;label&quot;: &quot;Approve invoice draft&quot;"
    assert spec_html =~ "&quot;to&quot;: &quot;approve_invoice&quot;"
    refute spec_html =~ "&quot;name&quot;: &quot;review_invoice&quot;"
  end

  test "edits action-backed step properties without dropping untouched opts", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    workflow_html =
      view
      |> element(~s(button[phx-value-id="restricted_issue_flow"]))
      |> render_click()

    assert workflow_html =~ "Restricted Issue Flow"

    selected_html =
      view
      |> element("#studio-node-open_issue")
      |> render_click()

    assert selected_html =~ ~s(id="studio-step-action-input")

    updated_html =
      view
      |> form("#studio-step-properties-form",
        step_properties: %{
          name: "notify_slack",
          label: "Notify Slack",
          action: "post_message"
        }
      )
      |> render_change()

    assert updated_html =~ ~s(id="studio-node-notify_slack")
    assert updated_html =~ "Notify Slack"
    assert updated_html =~ "post_message"
    assert updated_html =~ "Slack bot token"

    spec_html =
      view
      |> element(~s(button[phx-value-surface="spec"]))
      |> render_click()

    assert spec_html =~ "&quot;name&quot;: &quot;notify_slack&quot;"
    assert spec_html =~ "&quot;action&quot;: &quot;post_message&quot;"
    assert spec_html =~ "&quot;title&quot;: &quot;Escalate invoice review&quot;"
  end

  test "shows inline step property errors and blocks validate and publish", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    view
    |> element(~s(button[phx-value-id="restricted_issue_flow"]))
    |> render_click()

    view
    |> element("#studio-node-open_issue")
    |> render_click()

    view
    |> form("#studio-step-properties-form",
      step_properties: %{
        name: "notify_slack",
        label: "Notify Slack",
        action: "post_message"
      }
    )
    |> render_change()

    invalid_html =
      view
      |> form("#studio-step-properties-form",
        step_properties: %{
          name: "invoice_added",
          label: "",
          action: "missing_action"
        }
      )
      |> render_change()

    assert invalid_html =~ "Step name must be unique."
    assert invalid_html =~ "Label can&#39;t be blank."
    assert invalid_html =~ "Action key is not available for this user."
    assert invalid_html =~ ~s(id="studio-node-notify_slack")

    validation_html =
      view
      |> element(~s(button[phx-click="validate_draft"]))
      |> render_click()

    assert validation_html =~ "Fix step property errors before validating."
    refute validation_html =~ "Draft passes Squidie editor validation."

    publish_html =
      view
      |> element(~s(button[phx-click="publish_draft"]))
      |> render_click()

    assert publish_html =~ "Fix step property errors before publishing."
    refute publish_html =~ "Published"
  end

  test "drops a catalog node onto the canvas at the reported coordinates", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    html =
      view
      |> render_hook("drop_catalog_node", %{
        "provider" => "slack",
        "action_key" => "post_message",
        "x" => 420,
        "y" => 260
      })

    assert html =~ ~s(id="studio-node-slack-post_message-2")
    assert html =~ "left: 420px; top: 260px;"
    assert html =~ "Post message added to the draft."
  end

  test "filters catalog entries by query across provider, description, and tags", %{conn: conn} do
    {:ok, view, html} = live(conn, "/host-studio/workflows/invoice_review")

    assert html =~ "Post message"
    assert html =~ "Create issue"
    assert html =~ ~s(id="studio-catalog-search-form")

    html =
      view
      |> form("#studio-catalog-search-form", catalog_filter: %{q: "chatops"})
      |> render_change()

    assert html =~ "Post message"
    refute html =~ "Create issue"

    html =
      view
      |> form("#studio-catalog-search-form", catalog_filter: %{q: "github"})
      |> render_change()

    assert html =~ "Create issue"
    assert html =~ "production only"
    refute html =~ "Post message"

    html =
      view
      |> form("#studio-catalog-search-form", catalog_filter: %{q: "calendar"})
      |> render_change()

    assert html =~ "No palette nodes match this search."
    assert html =~ "Try a broader search or clear the current filter."
    refute html =~ "Post message"
    refute html =~ "Create issue"
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

  test "keeps centered node positions after validating a draft", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/host-studio/workflows/invoice_review")

    centered_html =
      view
      |> render_hook("center_graph", %{"width" => 1200, "height" => 600})

    [_, left, top] =
      Regex.run(
        ~r/id="studio-node-review_invoice"[^>]*style="left: (\d+)px; top: (\d+)px;"/,
        centered_html
      )

    validated_html =
      view
      |> element(~s(button[phx-click="validate_draft"]))
      |> render_click()

    assert validated_html =~ "Valid draft"
    assert validated_html =~ "left: #{left}px; top: #{top}px;"
  end

  test "rejects dropped catalog nodes in read-only mode", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/read-only-studio/workflows/invoice_review")

    html =
      view
      |> render_hook("drop_catalog_node", %{
        "provider" => "slack",
        "action_key" => "post_message",
        "x" => 420,
        "y" => 260
      })

    refute html =~ ~s(id="studio-node-slack-post_message-2")
    assert html =~ "Read-only access cannot change drafts."
  end
end
