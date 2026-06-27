defmodule SquidStudio.Web.Resolver do
  @moduledoc """
  Behavior for host applications that embed Squid Studio.

  The default resolver exposes sample workflows so the embedded UI can render
  before a host app wires in real Squidie workflow discovery.
  """

  alias SquidStudio.ConnectorCatalog
  alias SquidStudio.Drafts

  @callback resolve_user(Plug.Conn.t()) :: term()
  @callback resolve_access(term()) :: :all | :read_only
  @callback resolve_workflows(term()) :: [map()]
  @callback resolve_drafts(term()) :: [map()] | {:ok, [map()]} | {:error, term()}
  @callback resolve_connector_catalog(term(), map()) ::
              [map()] | {:ok, [map()]} | {:error, term()}
  @callback load_draft(term(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback create_draft(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  @callback save_draft(term(), map()) :: {:ok, map()} | {:error, term()}
  @callback delete_draft(term(), String.t()) :: :ok | {:ok, term()} | {:error, term()}
  @callback publish_draft(term(), String.t()) :: {:ok, map()} | {:error, term()}

  @optional_callbacks resolve_user: 1,
                      resolve_access: 1,
                      resolve_workflows: 1,
                      resolve_drafts: 1,
                      resolve_connector_catalog: 2,
                      load_draft: 2,
                      create_draft: 3,
                      save_draft: 2,
                      delete_draft: 2,
                      publish_draft: 2

  def call_with_fallback(resolver, callback, args) do
    if Code.ensure_loaded?(resolver) and function_exported?(resolver, callback, length(args)) do
      apply(resolver, callback, args)
    else
      apply(__MODULE__, callback, args)
    end
  end

  @doc false
  def resolve_user(_conn), do: nil

  @doc false
  def resolve_access(_user), do: :all

  @doc false
  def resolve_workflows(_user) do
    [
      %{
        id: "daily_digest",
        name: "Daily RSS To Discord",
        nodes: [
          node("daily_digest", "trigger :daily_digest", :trigger, 0, 80),
          node("fetch_feed", "step :fetch_feed", :step, 240, 80),
          node("build_digest", "step :build_digest", :step, 480, 80),
          node("post_to_discord", "step :post_to_discord", :retry, 720, 80),
          node("complete", ":complete", :terminal, 960, 80),
          node("record_failed_delivery", "failure route", :failure, 960, 220)
        ],
        edges: [
          %{id: "daily_digest-fetch_feed", source: "daily_digest", target: "fetch_feed"},
          %{id: "fetch_feed-build_digest", source: "fetch_feed", target: "build_digest"},
          %{
            id: "build_digest-post_to_discord",
            source: "build_digest",
            target: "post_to_discord"
          },
          %{id: "post_to_discord-complete", source: "post_to_discord", target: "complete"},
          %{
            id: "post_to_discord-record_failed_delivery",
            source: "post_to_discord",
            target: "record_failed_delivery"
          }
        ]
      },
      %{
        id: "approval_saga",
        name: "Approval Saga With Compensation",
        nodes: [
          node("start_request", "trigger :purchase_request", :trigger, 0, 80),
          node("reserve_budget", "step :reserve_budget", :step, 240, 80),
          node("manager_vote", "approval :manager_vote", :approval, 480, 80),
          node("release_order", "step :release_order", :step, 720, 80),
          node("rollback_budget", "compensate :rollback_budget", :failure, 720, 220)
        ],
        edges: [
          %{
            id: "start_request-reserve_budget",
            source: "start_request",
            target: "reserve_budget"
          },
          %{id: "reserve_budget-manager_vote", source: "reserve_budget", target: "manager_vote"},
          %{id: "manager_vote-release_order", source: "manager_vote", target: "release_order"},
          %{id: "manager_vote-rollback_budget", source: "manager_vote", target: "rollback_budget"}
        ]
      },
      %{
        id: "dynamic_fanout",
        name: "Dynamic Subscription Fanout",
        nodes: [
          node("manual_digest", "trigger :manual_digest", :trigger, 0, 80),
          node("preview_dynamic_work", "preview_dynamic_work/3", :step, 240, 80),
          node("schedule_dynamic_nodes", "schedule_dynamic_work/3", :step, 520, 80),
          node("inspect_overlay", "inspect_run_graph/2", :terminal, 800, 80)
        ],
        edges: [
          %{
            id: "manual_digest-preview_dynamic_work",
            source: "manual_digest",
            target: "preview_dynamic_work"
          },
          %{
            id: "preview_dynamic_work-schedule_dynamic_nodes",
            source: "preview_dynamic_work",
            target: "schedule_dynamic_nodes"
          },
          %{
            id: "schedule_dynamic_nodes-inspect_overlay",
            source: "schedule_dynamic_nodes",
            target: "inspect_overlay"
          }
        ]
      },
      %{
        id: "bedrock_dispatch",
        name: "Bedrock Lease Drain",
        nodes: [
          node("cron_payload", "trigger :cron_payload", :trigger, 0, 80),
          node("claim_payload", "Bedrock lease", :step, 240, 80),
          node("execute_next", "Squidie.execute_next/1", :step, 500, 80),
          node("renew_claim", "heartbeat", :retry, 760, 80)
        ],
        edges: [
          %{id: "cron_payload-claim_payload", source: "cron_payload", target: "claim_payload"},
          %{id: "claim_payload-execute_next", source: "claim_payload", target: "execute_next"},
          %{id: "execute_next-renew_claim", source: "execute_next", target: "renew_claim"}
        ]
      },
      %{
        id: "runtime_authored_spec",
        name: "Runtime Authored Spec",
        nodes: [
          node("draft_spec", "EditorSpec.validate_map/2", :trigger, 0, 80),
          node("preview_graph", "EditorSpec.preview_graph/2", :step, 280, 80),
          node("start_spec", "Squidie.start_spec/4", :step, 560, 80),
          node("inspect_run", "inspect_run/2", :terminal, 840, 80)
        ],
        edges: [
          %{id: "draft_spec-preview_graph", source: "draft_spec", target: "preview_graph"},
          %{id: "preview_graph-start_spec", source: "preview_graph", target: "start_spec"},
          %{id: "start_spec-inspect_run", source: "start_spec", target: "inspect_run"}
        ]
      }
    ]
  end

  @doc false
  def resolve_drafts(user), do: user |> resolve_workflows() |> Drafts.from_workflows()

  @doc false
  def resolve_connector_catalog(_user, _context) do
    [
      %{
        provider: "built_in",
        category: "Triggers",
        action_key: "manual_trigger",
        display_name: "Manual trigger",
        description: "Start a workflow from a host-approved payload.",
        input_contract: %{payload: "map"},
        output_contract: %{run_id: "string"},
        credential_requirements: [],
        enabled: true
      },
      %{
        provider: "built_in",
        category: "Actions",
        action_key: "action_step",
        display_name: "Action step",
        description: "Run a host-owned Squidie step.",
        input_contract: %{input: "map"},
        output_contract: %{result: "map"},
        credential_requirements: [],
        enabled: true
      },
      %{
        provider: "built_in",
        category: "Decisions",
        action_key: "manual_decision",
        display_name: "Manual decision",
        description: "Pause for an operator approval or rejection.",
        input_contract: %{subject: "string"},
        output_contract: %{decision: "string"},
        credential_requirements: [],
        enabled: true
      },
      %{
        provider: "built_in",
        category: "Routes",
        action_key: "failure_route",
        display_name: "Failure route",
        description: "Route a failed branch to host-owned recovery.",
        input_contract: %{error: "map"},
        output_contract: %{handled: "boolean"},
        credential_requirements: [],
        enabled: true
      }
    ]
    |> ConnectorCatalog.normalize_many()
  end

  @doc false
  def load_draft(user, draft_id) do
    user
    |> resolve_drafts()
    |> Enum.find(&(&1["id"] == draft_id))
    |> case do
      nil -> {:error, :not_found}
      draft -> {:ok, draft}
    end
  end

  @doc false
  def create_draft(_user, _workflow_id, _draft), do: {:error, :persistence_not_configured}

  @doc false
  def save_draft(_user, _draft), do: {:error, :persistence_not_configured}

  @doc false
  def delete_draft(_user, _draft_id), do: {:error, :persistence_not_configured}

  @doc false
  def publish_draft(_user, _draft_id), do: {:error, :publish_not_configured}

  defp node(id, label, type, x, y) do
    %{id: id, type: type, position: %{x: x, y: y}, data: %{label: label}}
  end
end
