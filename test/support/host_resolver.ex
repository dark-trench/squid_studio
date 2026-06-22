defmodule SquidStudio.Test.HostResolver do
  @moduledoc false

  @behaviour SquidStudio.Web.Resolver

  @impl true
  def resolve_user(_conn), do: :operator

  @impl true
  def resolve_access(:operator), do: :all

  @impl true
  def resolve_workflows(:operator) do
    [
      %{
        id: "invoice_review",
        name: "Invoice Review",
        nodes: [
          node("invoice_added", "trigger :invoice_added", :trigger, 0, 80),
          node("review_invoice", "step :review_invoice", :step, 240, 80)
        ],
        edges: [
          %{id: "invoice_added-review_invoice", source: "invoice_added", target: "review_invoice"}
        ]
      }
    ]
  end

  @impl true
  def resolve_drafts(:operator) do
    [
      draft("invoice_review", "Invoice Review"),
      draft("carrier_onboarding", "Carrier Onboarding",
        validation_errors: [
          %{
            path: ["steps", "2", "name"],
            message: "duplicate step name: review_invoice"
          },
          %{
            path: ["transitions", "0", "on"],
            message: "transition outcome must be ok or error"
          }
        ],
        spec: invalid_carrier_onboarding_spec()
      )
    ]
  end

  @impl true
  def resolve_connector_catalog(:operator, %{environment: :test}) do
    [
      %{
        provider: "slack",
        category: "Messaging",
        action_key: "post_message",
        display_name: "Post message",
        description: "Send an approved Slack message",
        tags: ["chatops", "alerts"],
        input_contract: %{channel: "string", text: "string"},
        output_contract: %{message_id: "string"},
        credential_requirements: [
          %{key: "slack_bot", label: "Slack bot token"}
        ],
        enabled: true
      },
      %{
        provider: "github",
        category: "Code",
        action_key: "create_issue",
        display_name: "Create issue",
        description: "Open a GitHub issue",
        tags: ["triage", "issue"],
        input_contract: %{title: "string"},
        output_contract: %{issue_url: "string"},
        credential_requirements: [%{key: "github_app", label: "GitHub app"}],
        enabled: false,
        authorized: false,
        disabled_reason: "production only"
      }
    ]
  end

  @impl true
  def save_draft(:operator, draft) do
    metadata =
      draft
      |> Map.get("metadata", %{})
      |> Map.put("last_saved_by", "host")

    {:ok, Map.put(draft, "metadata", metadata)}
  end

  @impl true
  def publish_draft(:operator, draft_id) do
    {:ok,
     %{
       "id" => "#{draft_id}:published",
       "definition_version" => "published",
       "source_draft_id" => draft_id
     }}
  end

  defp draft(id, name, extra \\ []) do
    draft =
      %{
        id: id,
        workflow: id,
        name: name,
        definition_version: "draft",
        spec: base_spec(id)
      }

    Enum.into(extra, draft)
  end

  defp base_spec(id) do
    %{
      workflow: id,
      definition_version: "draft",
      triggers: [],
      payload: [],
      steps: [
        %{name: "invoice_added", opts: []},
        %{name: "review_invoice", opts: []}
      ],
      transitions: [
        %{from: "invoice_added", on: "ok", to: "review_invoice"}
      ],
      retries: [],
      entry_steps: ["invoice_added"],
      initial_step: "invoice_added",
      entry_step: "invoice_added",
      editor: %{
        nodes: %{
          invoice_added: %{label: "Invoice added", type: "trigger", x: 24, y: 96},
          review_invoice: %{label: "Review invoice draft", type: "step", x: 332, y: 168}
        }
      }
    }
  end

  defp invalid_carrier_onboarding_spec do
    %{
      workflow: "carrier_onboarding",
      definition_version: "draft",
      triggers: [],
      payload: [],
      steps: [
        %{name: "invoice_added", opts: []},
        %{name: "review_invoice", opts: []},
        %{name: "review_invoice", opts: []}
      ],
      transitions: [
        %{from: "invoice_added", on: "pending", to: "review_invoice"}
      ],
      retries: [],
      entry_steps: ["invoice_added"],
      initial_step: "invoice_added",
      entry_step: "invoice_added"
    }
  end

  defp node(id, label, type, x, y) do
    %{id: id, type: type, position: %{x: x, y: y}, data: %{label: label}}
  end
end
