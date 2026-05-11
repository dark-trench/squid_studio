defmodule SquidStudioDash.Resolver do
  @moduledoc false

  @behaviour SquidStudio.Web.Resolver

  @impl true
  def resolve_user(_conn), do: nil

  @impl true
  def resolve_access(_user), do: :all

  @impl true
  def resolve_workflows(_user) do
    [
      %{
        id: "customer_onboarding",
        name: "Customer Onboarding",
        nodes: [
          node("start", "New account", :input, 0, 140),
          node("validate", "Validate profile", :default, 260, 80),
          node("risk", "Risk review", :default, 520, 80),
          node("approval", "Manual approval", :default, 520, 220),
          node("provision", "Provision workspace", :default, 780, 140),
          node("notify", "Send welcome", :output, 1040, 140)
        ],
        edges: [
          edge("start", "validate"),
          edge("validate", "risk"),
          edge("validate", "approval"),
          edge("risk", "provision"),
          edge("approval", "provision"),
          edge("provision", "notify")
        ]
      }
    ]
  end

  defp node(id, label, type, x, y) do
    %{id: id, type: type, position: %{x: x, y: y}, data: %{label: label}}
  end

  defp edge(source, target) do
    %{id: "#{source}-#{target}", source: source, target: target}
  end
end
