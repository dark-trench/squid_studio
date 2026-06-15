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
      draft("carrier_onboarding", "Carrier Onboarding")
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

  defp draft(id, name) do
    %{
      id: id,
      workflow: id,
      name: name,
      definition_version: "draft",
      spec: %{
        workflow: id,
        definition_version: "draft",
        steps: [%{name: "review_invoice", opts: []}],
        transitions: []
      }
    }
  end

  defp node(id, label, type, x, y) do
    %{id: id, type: type, position: %{x: x, y: y}, data: %{label: label}}
  end
end
