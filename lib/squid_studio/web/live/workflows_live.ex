defmodule SquidStudio.Web.WorkflowsLive do
  @moduledoc false

  use SquidStudio.Web, :live_view

  @status_filters ~w(all running approval draft dynamic)

  @impl true
  def mount(_params, _session, socket) do
    workflows =
      socket.assigns.workflows
      |> List.wrap()
      |> Enum.map(&workflow_card/1)

    drafts = List.wrap(socket.assigns[:drafts])
    query = ""
    status_filter = "all"

    socket =
      socket
      |> assign(:page_title, "Workflows")
      |> assign(:theme, :system)
      |> assign(:query, query)
      |> assign(:status_filter, status_filter)
      |> assign(:filter_form, filter_form(query))
      |> assign(:workflows, workflows)
      |> assign(:drafts, drafts)
      |> assign(:templates, templates())
      |> assign(:selected_template_id, "approval_gate")
      |> assign(:resource_views, resource_views())
      |> assign_visible_workflows()

    {:ok, socket}
  end

  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, normalize_theme(theme))}
  end

  def handle_event("filter_workflows", %{"workflow_filter" => params}, socket) do
    query = Map.get(params, "q", "")

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filter_form, filter_form(query))
     |> assign_visible_workflows()}
  end

  def handle_event("set_status_filter", %{"status" => status}, socket) do
    status = if status in @status_filters, do: status, else: "all"

    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign_visible_workflows()}
  end

  def handle_event("select_template", %{"id" => id}, socket) do
    template =
      Enum.find(socket.assigns.templates, &(&1.id == id)) || List.first(socket.assigns.templates)

    {:noreply, assign(socket, :selected_template_id, template.id)}
  end

  defp assign_visible_workflows(socket) do
    visible_workflows =
      socket.assigns.workflows
      |> filter_by_status(socket.assigns.status_filter)
      |> filter_by_query(socket.assigns.query)

    assign(socket, :visible_workflows, visible_workflows)
  end

  defp filter_by_status(workflows, "all"), do: workflows

  defp filter_by_status(workflows, status) do
    Enum.filter(workflows, &(&1.status == status))
  end

  defp filter_by_query(workflows, ""), do: workflows

  defp filter_by_query(workflows, query) do
    query = query |> String.downcase() |> String.trim()

    Enum.filter(workflows, fn workflow ->
      searchable =
        [
          workflow.name,
          workflow.description,
          workflow.status_label,
          workflow.executor,
          workflow.primary_action
        ]
        |> Enum.join(" ")
        |> String.downcase()

      String.contains?(searchable, query)
    end)
  end

  defp workflow_card(workflow) do
    id = workflow |> value(:id, "workflow") |> to_string()
    name = workflow |> value(:name, "Workflow") |> to_string()
    nodes = List.wrap(Map.get(workflow, :nodes) || Map.get(workflow, "nodes"))
    edges = List.wrap(Map.get(workflow, :edges) || Map.get(workflow, "edges"))
    status = status_for(id)

    %{
      id: id,
      name: name,
      status: status,
      status_label: status_label(status),
      description: description_for(id),
      nodes: length(nodes),
      edges: length(edges),
      runs: runs_for(id),
      approvals: approvals_for(id),
      dynamic_overlays: dynamic_overlays_for(id),
      executor: executor_for(id),
      primary_action: primary_action_for(id),
      updated: updated_for(id)
    }
  end

  defp status_for("approval_saga"), do: "approval"
  defp status_for("dynamic_fanout"), do: "dynamic"
  defp status_for("runtime_authored_spec"), do: "draft"
  defp status_for(_id), do: "running"

  defp status_label("approval"), do: "Waiting for approval"
  defp status_label("dynamic"), do: "Dynamic work scheduled"
  defp status_label("draft"), do: "Draft spec"
  defp status_label("running"), do: "Running"

  defp description_for("approval_saga"),
    do: "Manual gates, compensation, and replay-safe recovery."

  defp description_for("dynamic_fanout"),
    do: "Preview, record, and schedule runtime graph patches."

  defp description_for("bedrock_dispatch"),
    do: "Host-owned Bedrock leases draining execute_next/1."

  defp description_for("runtime_authored_spec"),
    do: "Validated editor JSON activated through start_spec/4."

  defp description_for(_id), do: "Host-owned worker execution with durable inspection."

  defp runs_for("daily_digest"), do: 128
  defp runs_for("approval_saga"), do: 42
  defp runs_for("dynamic_fanout"), do: 18
  defp runs_for("bedrock_dispatch"), do: 317
  defp runs_for(_id), do: 7

  defp approvals_for("approval_saga"), do: 3
  defp approvals_for(_id), do: 0

  defp dynamic_overlays_for("dynamic_fanout"), do: 6
  defp dynamic_overlays_for(_id), do: 0

  defp executor_for("bedrock_dispatch"), do: "Bedrock lease runner"
  defp executor_for(_id), do: "Host worker"

  defp primary_action_for("runtime_authored_spec"), do: "Start spec"
  defp primary_action_for("approval_saga"), do: "Review gate"
  defp primary_action_for("dynamic_fanout"), do: "Inspect overlay"
  defp primary_action_for(_id), do: "Open editor"

  defp updated_for("daily_digest"), do: "2 minutes ago"
  defp updated_for("approval_saga"), do: "waiting 18 minutes"
  defp updated_for("dynamic_fanout"), do: "scheduled today"
  defp updated_for("bedrock_dispatch"), do: "lease renewed"
  defp updated_for(_id), do: "draft updated"

  defp resource_views do
    [
      %{
        label: "All workflows",
        status: "all",
        detail: "Host inventory"
      },
      %{
        label: "Running",
        status: "running",
        detail: "Active drains"
      },
      %{
        label: "Approval inbox",
        status: "approval",
        detail: "Manual gates"
      },
      %{
        label: "Dynamic work",
        status: "dynamic",
        detail: "Runtime overlays"
      },
      %{
        label: "Draft specs",
        status: "draft",
        detail: "Editor JSON"
      }
    ]
  end

  defp templates do
    [
      %{
        id: "approval_gate",
        title: "Approval gate",
        meta: "manual gates",
        description: "Purchase or release flows with approve/reject signals and compensation."
      },
      %{
        id: "dynamic_fanout",
        title: "Dynamic fanout",
        meta: "dynamic work",
        description:
          "Runtime generated child work with graph overlays and action registry checks."
      },
      %{
        id: "bedrock_lease",
        title: "Host execution",
        meta: "host execution",
        description: "Backend-owned delivery with leases and bounded execute_next/1 drains."
      }
    ]
  end

  defp selected_template(templates, selected_id) do
    Enum.find(templates, &(&1.id == selected_id)) || List.first(templates)
  end

  defp selected_resource_view(resource_views, selected_status) do
    Enum.find(resource_views, &(&1.status == selected_status)) || List.first(resource_views)
  end

  defp filter_form(query) do
    to_form(%{"q" => query}, as: :workflow_filter)
  end

  defp normalize_theme(theme) when theme in ~w(system light dark),
    do: String.to_existing_atom(theme)

  defp normalize_theme(theme) when theme in [:system, :light, :dark], do: theme
  defp normalize_theme(_theme), do: :system

  defp status_filter_class(active, value) do
    if active == value, do: "is-active", else: nil
  end

  defp resource_view_count(workflows, "all"), do: length(workflows)

  defp resource_view_count(workflows, status) do
    workflows
    |> filter_by_status(status)
    |> length()
  end

  defp status_class(status), do: "is-#{status}"

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key) || Map.get(map, to_string(key)) || default
end
