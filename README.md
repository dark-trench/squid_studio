# Squid Studio

Visual editor for Squidie workflows.

> [!WARNING]
> Squid Studio is under active development and is not usable yet. APIs,
> installation steps, embedded UI behavior, and workflow-authoring surfaces may
> change before an initial usable release.

## Squidie Integration

Squid Studio uses Squidie as the workflow runtime and editor-spec boundary.
Studio owns the embedded Phoenix UI; host applications still own runtime
configuration, storage, queues, workers, authorization, and redaction.

Add both packages to a host application when the Studio UI should author,
validate, preview, or inspect Squidie workflows:

```elixir
defp deps do
  [
    {:squidie, "~> 0.1.3"},
    {:squid_studio, "~> 0.1.0"}
  ]
end
```

Hosts should configure Squidie directly in the host application:

```elixir
config :squidie,
  repo: MyApp.Repo,
  queue: "default"
```

Squid Studio does not start workers or choose storage. Host applications expose
only the workflows, runs, action registry, and visibility scope that a user is
allowed to access.

## Embed In A Phoenix App

Add Squid Studio as a dependency, then mount it from the host router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  import SquidStudio.Web.Router

  scope "/dev" do
    pipe_through :browser

    squid_studio "/squid-studio"
  end
end
```

Host applications can provide workflow data by implementing `SquidStudio.Web.Resolver`:

```elixir
defmodule MyApp.SquidStudioResolver do
  @behaviour SquidStudio.Web.Resolver

  @impl true
  def resolve_user(conn), do: conn.assigns[:current_user]

  @impl true
  def resolve_access(_user), do: :all

  @impl true
  def resolve_workflows(_user) do
    [
      %{
        id: "workflow",
        name: "Workflow",
        nodes: [],
        edges: []
      }
    ]
  end
end
```

Then pass it to the mount macro:

```elixir
squid_studio "/squid-studio", resolver: MyApp.SquidStudioResolver
```

For a fuller host checklist covering resolver callbacks, action catalogs, draft
persistence, run operations, and redaction boundaries, see
[docs/host_integration.md](docs/host_integration.md). For the current V1 trust
boundary review and deferred security surfaces, see
[docs/v1_security_review.md](docs/v1_security_review.md).

## Standalone Development

```sh
mix deps.get
mix assets.build
cd standalone
mix phx.server
```

Visit `http://localhost:4000`.

Run validation with:

```sh
mix precommit
```

Release maintainers should also follow
[docs/release_checklist.md](docs/release_checklist.md) before tagging or
publishing the first V1 package, alongside the V1 review notes in
[docs/v1_security_review.md](docs/v1_security_review.md).
