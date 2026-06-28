defmodule SquidStudio.Web.WorkflowsLive do
  @moduledoc false

  use SquidStudio.Web, :live_view

  alias SquidStudio.Drafts
  alias SquidStudio.Web.Resolver

  @status_filters ~w(all running approval draft dynamic)

  @impl true
  def mount(_params, _session, socket) do
    workflow_inventory =
      socket.assigns.workflows
      |> List.wrap()

    workflows =
      workflow_inventory
      |> Enum.map(&workflow_card/1)

    drafts =
      socket.assigns[:drafts]
      |> List.wrap()

    query = ""
    status_filter = "all"

    socket =
      socket
      |> assign(:page_title, "Workflows")
      |> assign(:theme, :system)
      |> assign(:query, query)
      |> assign(:status_filter, status_filter)
      |> assign(:filter_form, filter_form(query))
      |> assign(:workflow_inventory, workflow_inventory)
      |> assign(:workflows, workflows)
      |> assign(:drafts, drafts)
      |> assign(:open_draft_menu_id, nil)
      |> assign(:pending_delete_draft_id, nil)
      |> assign(:persistence_message, nil)
      |> assign(:selected_draft_id, List.first(drafts) |> then(&(&1 && Map.get(&1, "id"))))
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

  def handle_event("create_draft", %{"workflow_id" => workflow_id}, socket) do
    workflow = Enum.find(socket.assigns.workflow_inventory, &(value(&1, :id, nil) == workflow_id))
    seed_draft = Drafts.create_seed(workflow || %{"id" => workflow_id, "name" => workflow_id})

    case Resolver.call_with_fallback(socket.assigns.resolver, :create_draft, [
           socket.assigns.user,
           workflow_id,
           seed_draft
         ]) do
      {:ok, created_draft} ->
        case Drafts.normalize(created_draft) do
          {:ok, normalized_draft} ->
            {:noreply,
             socket
             |> assign(:drafts, upsert_draft(socket.assigns.drafts, normalized_draft))
             |> assign(:selected_draft_id, Map.get(normalized_draft, "id"))
             |> assign(:persistence_message, "Host created a new draft.")}

          {:error, _reason} ->
            {:noreply,
             assign(socket, :persistence_message, create_draft_error_message(:invalid_draft_data))}
        end

      {:error, reason} ->
        {:noreply, assign(socket, :persistence_message, create_draft_error_message(reason))}
    end
  end

  def handle_event("toggle_draft_menu", %{"id" => id}, socket) do
    open_draft_menu_id = if socket.assigns.open_draft_menu_id == id, do: nil, else: id

    {:noreply,
     socket
     |> assign(:open_draft_menu_id, open_draft_menu_id)
     |> assign(:pending_delete_draft_id, nil)}
  end

  def handle_event("request_delete_draft", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:open_draft_menu_id, id)
     |> assign(:pending_delete_draft_id, id)}
  end

  def handle_event("cancel_delete_draft", _params, socket) do
    {:noreply,
     socket
     |> assign(:open_draft_menu_id, nil)
     |> assign(:pending_delete_draft_id, nil)}
  end

  def handle_event("confirm_delete_draft", %{"id" => id}, socket) do
    case Resolver.call_with_fallback(socket.assigns.resolver, :delete_draft, [
           socket.assigns.user,
           id
         ]) do
      :ok ->
        {:noreply,
         socket
         |> remove_draft(id)
         |> assign(:open_draft_menu_id, nil)
         |> assign(:pending_delete_draft_id, nil)
         |> assign(:persistence_message, "Host deleted the draft.")}

      {:ok, _result} ->
        {:noreply,
         socket
         |> remove_draft(id)
         |> assign(:open_draft_menu_id, nil)
         |> assign(:pending_delete_draft_id, nil)
         |> assign(:persistence_message, "Host deleted the draft.")}

      {:error, reason} ->
        {:noreply, assign(socket, :persistence_message, delete_draft_error_message(reason))}
    end
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
          workflow.run_state,
          workflow.run_detail
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
      icon: icon_for(status),
      nodes: length(nodes),
      edges: length(edges),
      runs: runs_for(id),
      approvals: approvals_for(id),
      dynamic_overlays: dynamic_overlays_for(id),
      executor: executor_for(id),
      updated: updated_for(id),
      run_state: run_state_for(id),
      run_detail: run_detail_for(id)
    }
  end

  defp icon_for("approval"), do: "hero-hand-raised"
  defp icon_for("dynamic"), do: "hero-cube"
  defp icon_for("draft"), do: "hero-document-text"
  defp icon_for("running"), do: "hero-bolt"

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

  defp updated_for("daily_digest"), do: "2 minutes ago"
  defp updated_for("approval_saga"), do: "waiting 18 minutes"
  defp updated_for("dynamic_fanout"), do: "scheduled today"
  defp updated_for("bedrock_dispatch"), do: "lease renewed"
  defp updated_for(_id), do: "draft updated"

  defp run_state_for("approval_saga"), do: "Approval gate"
  defp run_state_for("dynamic_fanout"), do: "Overlay queued"
  defp run_state_for("runtime_authored_spec"), do: "Draft validation"
  defp run_state_for("bedrock_dispatch"), do: "Lease drain"
  defp run_state_for(_id), do: "Healthy drain"

  defp run_detail_for("daily_digest"), do: "Last run delivered 12 feed items"
  defp run_detail_for("approval_saga"), do: "3 approvals waiting on operator signal"
  defp run_detail_for("dynamic_fanout"), do: "6 dynamic branches ready to inspect"
  defp run_detail_for("bedrock_dispatch"), do: "Next lease renews on the host worker"
  defp run_detail_for(_id), do: "Spec saved and waiting for activation"

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

  defp upsert_draft(drafts, draft) do
    draft_id = Map.get(draft, "id")

    case Enum.any?(drafts, &(Map.get(&1, "id") == draft_id)) do
      true -> Enum.map(drafts, &replace_draft(&1, draft_id, draft))
      false -> drafts ++ [draft]
    end
  end

  defp remove_draft(socket, id) do
    drafts = Enum.reject(socket.assigns.drafts, &(Map.get(&1, "id") == id))

    selected_draft_id =
      if socket.assigns.selected_draft_id == id, do: nil, else: socket.assigns.selected_draft_id

    socket
    |> assign(:drafts, drafts)
    |> assign(:selected_draft_id, selected_draft_id)
  end

  defp replace_draft(existing, draft_id, draft) do
    if Map.get(existing, "id") == draft_id, do: draft, else: existing
  end

  defp create_draft_error_message(:persistence_not_configured),
    do: "Host draft creation is not available."

  defp create_draft_error_message(:invalid_draft_data),
    do: "Host returned invalid draft data."

  defp create_draft_error_message(_reason),
    do: "Host draft creation failed."

  defp delete_draft_error_message(:persistence_not_configured),
    do: "Host draft deletion is not available."

  defp delete_draft_error_message(_reason),
    do: "Host draft deletion failed."

  defp workflow_state_title(error, _workflows, _query, _status_filter) when not is_nil(error),
    do: "Workflow inventory unavailable."

  defp workflow_state_title(_error, workflows, "", "all") when workflows == [],
    do: "No workflows available."

  defp workflow_state_title(_error, _workflows, _query, _status_filter),
    do: "No workflows match this view."

  defp workflow_state_message(error, _workflows, _query, _status_filter) when not is_nil(error),
    do: "Host workflow data is temporarily unavailable."

  defp workflow_state_message(_error, workflows, "", "all") when workflows == [],
    do: "Host has not exposed workflows yet."

  defp workflow_state_message(_error, _workflows, _query, _status_filter),
    do: "Try a broader search or clear the current filter."

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
