# Host Integration Guide

Squid Studio ships an embedded Phoenix UI for editing and inspecting Squidie
workflows. The host application still owns execution, storage, authorization,
and data visibility. This guide shows the minimum wiring needed to embed Studio
without leaking those responsibilities into the library.

## Integration Model

Studio owns:

- Router and LiveView mounting.
- Editor and workflow inventory UI.
- Draft validation through Squidie's editor-spec boundary.
- Host-safe rendering of workflow, draft, and catalog metadata.

The host owns:

- Authentication and authorization.
- Workflow discovery and run lookup.
- Draft persistence and publish behavior.
- Action registry and execution policy.
- Redaction of sensitive payloads and operator-only metadata.

Studio should only receive data the current user is allowed to see.

## 1. Add Dependencies

Add Squidie and Squid Studio to the host application:

```elixir
defp deps do
  [
    {:squidie, "~> 0.3.0"},
    {:squid_studio, "~> 0.1.0"}
  ]
end
```

Configure Squidie in the host application as usual:

```elixir
config :squidie,
  repo: MyApp.Repo,
  queue: "default"
```

Studio does not start workers, select queues, or choose persistence.

## 2. Mount The Router

Import the router helper and mount Studio inside a browser pipeline:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import SquidStudio.Web.Router

  scope "/ops" do
    pipe_through :browser

    squid_studio "/studio", resolver: MyApp.SquidStudioResolver
  end
end
```

The mounted prefix becomes the base for Studio routes and static assets.

## 3. Implement A Resolver

The resolver is the host boundary. It decides which user is active, what
surface they can access, which workflows and drafts exist, and which actions
are safe to expose.

```elixir
defmodule MyApp.SquidStudioResolver do
  @behaviour SquidStudio.Web.Resolver

  alias Squidie.Workflow.ActionRegistry

  @impl true
  def resolve_user(conn), do: conn.assigns.current_user

  @impl true
  def resolve_access(user) do
    if Accounts.can_edit_workflows?(user), do: :all, else: :read_only
  end

  @impl true
  def resolve_workflows(user) do
    Workflows.list_visible_workflows(user)
  end

  @impl true
  def resolve_drafts(user) do
    DraftStore.list_visible_drafts(user)
  end

  @impl true
  def resolve_connector_catalog(user, _context) do
    user
    |> WorkflowPolicies.visible_action_registry()
    |> ActionRegistry.catalog()
    |> case do
      {:ok, catalog} -> catalog
      {:error, {:invalid_action_catalog, errors}} -> {:error, errors}
    end
  end

  @impl true
  def save_draft(user, draft) do
    DraftStore.save_visible_draft(user, draft)
  end

  @impl true
  def publish_draft(user, draft_id) do
    DraftStore.publish_visible_draft(user, draft_id)
  end
end
```

Keep authorization in the host layer. Studio should not infer permissions from
workflow content or runtime state.

## 4. Resolver Callback Expectations

`resolve_user/1`

- Derive the host user or actor from the incoming connection.
- Return a stable value the other callbacks can authorize against.

`resolve_access/1`

- Return `:all` for editable access.
- Return `:read_only` for view-only access.
- Use `:read_only` when a user may inspect a workflow but must not mutate it.

`resolve_workflows/1`

- Return only workflows visible to the current user.
- Prefer IDs and names that stay stable across refreshes.
- Keep runtime-only or sensitive fields out of the editor surface.

`resolve_drafts/1`

- Return JSON-safe draft maps.
- Preserve editor metadata needed for validation, persistence, and export.
- Include validation errors only when the host has already computed them and
  wants Studio to render them immediately.

`resolve_connector_catalog/2`

- Treat this as the host-approved node catalog.
- Expose stable action keys, display metadata, contracts, and availability.
- Do not expose executable modules, secrets, or raw credentials.

`save_draft/2`

- Persist the provided JSON-safe draft map.
- Return the saved draft payload that Studio should continue rendering.
- Reject writes that bypass host authorization or tenant boundaries.

`publish_draft/2`

- Publish only after host-side validation, policy checks, and any required
  evaluation gates.
- Return host-owned version metadata, not secrets or private runtime payloads.

## 5. Action Catalog And Controlled Execution

Studio can render action metadata, but the host must remain the execution trust
boundary.

Recommended policy:

1. Keep a host-owned action registry keyed by stable action names.
2. Project that registry into Studio's connector catalog.
3. Validate, publish, and execute drafts against the same allowlist.
4. Hide or disable actions when the current user lacks access.

Do not let Studio resolve arbitrary modules, credentials, or runtime-side
execution options from user-controlled input.

## 6. Draft Persistence

Drafts are host-owned records. Studio passes JSON-safe editor payloads across
the resolver boundary; the host decides how they are stored.

Good host behavior:

- Version drafts explicitly.
- Keep editor metadata separate from runtime history.
- Validate before accepting destructive changes.
- Return structured errors when a draft cannot be saved or published.

Avoid:

- Storing secrets inside draft specs.
- Persisting runtime-owned history inside the editable draft payload.
- Letting Studio choose database schema or retention rules.

## 7. Run Operations And Inspection

If the host later exposes run listing, run graphs, approvals, replay, or
cancel/resume controls, keep those callbacks and commands host-owned too.

Studio should only become an operator surface over host-authorized data and
operations. The host remains responsible for:

- Which runs are visible.
- Which run fields are redacted.
- Which operators may cancel, replay, approve, or reject.
- Which workflow versions can be executed.

## 8. Redaction And Authorization

Treat Studio as a read model fed by host policy.

Before assigning data into Studio:

- Remove secrets, tokens, and credential values.
- Redact payload fields that the current user should not inspect.
- Split editable builder data from operator-only runtime data when those scopes
  differ.
- Make auditor, operator, and read-only behavior explicit in the resolver.

Read-only users should never receive edit capability through hidden controls or
client-side affordances alone. The host must enforce that boundary through the
resolver callbacks it exposes.

## 9. Minimal Integration Checklist

- Add `:squidie` and `:squid_studio` deps.
- Mount `squid_studio/2` in a browser scope.
- Implement `SquidStudio.Web.Resolver`.
- Return only authorized workflows, drafts, and catalog entries.
- Keep draft persistence host-owned.
- Validate and publish against a host-controlled action allowlist.
- Redact sensitive fields before Studio sees them.
