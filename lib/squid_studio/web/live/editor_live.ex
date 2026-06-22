defmodule SquidStudio.Web.EditorLive do
  @moduledoc false

  use SquidStudio.Web, :live_view

  alias Squidie.Workflow.EditorSpec
  alias SquidStudio.ConnectorCatalog
  alias SquidStudio.Drafts
  alias SquidStudio.EditorGraph
  alias SquidStudio.Web.Resolver

  @node_width 160
  @node_height 76
  @canvas_padding 40

  @impl true
  def mount(params, _session, socket) do
    workflow =
      socket.assigns.workflows
      |> List.wrap()
      |> select_workflow(params["workflow_id"])
      |> normalize_workflow()

    drafts = List.wrap(socket.assigns[:drafts])
    selected_draft = List.first(drafts)
    connector_catalog = List.wrap(socket.assigns[:connector_catalog])
    catalog_query = ""

    socket =
      socket
      |> assign(:page_title, "Editor")
      |> assign(:read_only?, socket.assigns.access == :read_only)
      |> assign(:editor_surface, :visual)
      |> assign(:workflow, workflow)
      |> assign(:drafts, drafts)
      |> assign(:selected_draft_id, draft_id(selected_draft))
      |> assign(:draft_status, draft_status(socket.assigns[:draft_error], selected_draft))
      |> assign(
        :persistence_message,
        persistence_message(socket.assigns[:draft_error], selected_draft)
      )
      |> assign(:nodes, [])
      |> assign(:edges, [])
      |> assign(:connector_catalog, connector_catalog)
      |> assign(:catalog_query, catalog_query)
      |> assign(:catalog_form, catalog_form(catalog_query))
      |> assign(:catalog_message, catalog_message(socket.assigns[:connector_catalog_error]))
      |> assign(:graph_centered?, false)
      |> assign(:selected_node_id, nil)
      |> assign(:selected_edge_id, nil)
      |> assign(:theme, :system)
      |> assign(:validation_checked?, false)
      |> assign_catalog_groups()
      |> assign_selected_graph()
      |> assign_spec_view()
      |> initialize_validation_feedback()

    {:ok, socket}
  end

  @impl true
  def handle_event("move_node", _params, %{assigns: %{read_only?: true}} = socket) do
    {:noreply, deny_draft_mutation(socket)}
  end

  @impl true
  def handle_event("move_node", %{"id" => id, "x" => x, "y" => y}, socket) do
    x = parse_coordinate(x)
    y = parse_coordinate(y)

    socket =
      case selected_draft(socket) do
        nil ->
          nodes =
            Enum.map(socket.assigns.nodes, fn
              %{id: ^id} = node -> %{node | x: x, y: y}
              node -> node
            end)

          assign(socket, nodes: nodes, edges: build_edges(socket.assigns.edges, nodes))

        _draft ->
          socket
          |> update_selected_draft_spec(&EditorGraph.update_node_position(&1, id, x, y))
          |> assign_selected_graph()
          |> assign_spec_view()
      end

    {:noreply, socket}
  end

  def handle_event("center_graph", %{"width" => width, "height" => height}, socket) do
    if socket.assigns.graph_centered? do
      {:noreply, socket}
    else
      nodes =
        center_nodes(socket.assigns.nodes, parse_coordinate(width), parse_coordinate(height))

      socket =
        socket
        |> assign(:nodes, nodes)
        |> assign(:edges, build_edges(socket.assigns.edges, nodes))
        |> assign(:graph_centered?, true)

      {:noreply, socket}
    end
  end

  def handle_event("select_node", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:selected_node_id, id) |> assign(:selected_edge_id, nil)}
  end

  def handle_event("set_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, normalize_theme(theme))}
  end

  def handle_event(
        "focus_validation_issue",
        %{"anchor_kind" => "node", "anchor_id" => id},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:editor_surface, :visual)
     |> assign(:selected_node_id, id)
     |> assign(:selected_edge_id, nil)}
  end

  def handle_event(
        "focus_validation_issue",
        %{"anchor_kind" => "edge", "anchor_id" => id},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:editor_surface, :visual)
     |> assign(:selected_edge_id, id)}
  end

  def handle_event("set_editor_surface", %{"surface" => surface}, socket) do
    {:noreply, assign(socket, :editor_surface, normalize_surface(surface))}
  end

  def handle_event("filter_catalog", %{"catalog_filter" => params}, socket) do
    query = Map.get(params, "q", "")

    {:noreply,
     socket
     |> assign(:catalog_query, query)
     |> assign(:catalog_form, catalog_form(query))
     |> assign_catalog_groups()}
  end

  def handle_event("validate_draft", _params, socket) do
    case selected_draft(socket) do
      nil ->
        {:noreply,
         socket
         |> assign(:validation_checked?, true)
         |> assign(:validation_status, "No draft")
         |> assign(:validation_message, "No draft spec is selected.")}

      draft ->
        spec = current_spec(draft, socket.assigns.workflow)

        case EditorSpec.validate_map(spec) do
          :ok ->
            {:noreply,
             socket
             |> refresh_saved_draft(Map.put(draft, "validation_errors", []))
             |> assign_spec_view()
             |> assign_validation_result(:ok)}

          {:error, {:invalid_workflow_editor_spec, errors}} ->
            {:noreply,
             socket
             |> refresh_saved_draft(
               Map.put(draft, "validation_errors", draft_validation_errors(errors))
             )
             |> assign_spec_view()
             |> assign_validation_result({:error, errors})}
        end
    end
  end

  def handle_event("select_draft", %{"id" => id}, socket) do
    draft = Enum.find(socket.assigns.drafts, &(Map.get(&1, "id") == id))

    {:noreply,
     socket
     |> assign(:selected_draft_id, id)
     |> assign(:draft_status, draft_status(nil, draft))
     |> assign(:persistence_message, persistence_message(nil, draft))
     |> assign_selected_graph()
     |> assign_spec_view()
     |> initialize_validation_feedback()}
  end

  def handle_event("add_catalog_node", _params, %{assigns: %{read_only?: true}} = socket) do
    {:noreply, deny_draft_mutation(socket)}
  end

  def handle_event("add_catalog_node", %{"action_key" => action_key} = params, socket) do
    connector =
      find_catalog_entry(socket.assigns.connector_catalog, params["provider"], action_key)

    cond do
      is_nil(connector) ->
        {:noreply, assign(socket, :catalog_message, "Connector unavailable.")}

      not catalog_entry_available?(connector) ->
        {:noreply,
         assign(
           socket,
           :catalog_message,
           "Connector unavailable: #{catalog_disabled_reason(connector)}"
         )}

      true ->
        node = catalog_entry_to_node(connector, length(socket.assigns.nodes))

        {:noreply,
         socket
         |> update_selected_draft_spec(&EditorGraph.add_action_step(&1, node, connector))
         |> assign_selected_graph(node.id)
         |> assign(:selected_edge_id, nil)
         |> assign_spec_view()
         |> initialize_validation_feedback()
         |> assign(
           :catalog_message,
           "#{Map.fetch!(connector, "display_name")} added to the draft."
         )}
    end
  end

  def handle_event("save_draft", _params, %{assigns: %{read_only?: true}} = socket) do
    {:noreply, deny_draft_mutation(socket)}
  end

  def handle_event("save_draft", _params, socket) do
    draft = selected_draft(socket)

    case draft &&
           Resolver.call_with_fallback(socket.assigns.resolver, :save_draft, [
             socket.assigns.user,
             draft
           ]) do
      {:ok, saved_draft} ->
        {:noreply,
         socket
         |> refresh_saved_draft(saved_draft)
         |> assign(:draft_status, "Saved")
         |> assign(:persistence_message, "Host persistence accepted the draft spec.")
         |> assign_spec_view()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:draft_status, "Unsaved")
         |> assign(:persistence_message, save_error_message(reason))}

      nil ->
        {:noreply,
         socket
         |> assign(:draft_status, "No draft")
         |> assign(:persistence_message, "No draft spec is selected.")}
    end
  end

  def handle_event("publish_draft", _params, %{assigns: %{read_only?: true}} = socket) do
    {:noreply, deny_draft_mutation(socket)}
  end

  def handle_event("publish_draft", _params, socket) do
    draft = selected_draft(socket)

    case draft &&
           Resolver.call_with_fallback(socket.assigns.resolver, :publish_draft, [
             socket.assigns.user,
             Map.get(draft, "id")
           ]) do
      {:ok, _version} ->
        {:noreply,
         socket
         |> assign(:draft_status, "Published")
         |> assign(:persistence_message, "Host published a runnable Squidie workflow version.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:draft_status, "Draft spec")
         |> assign(:persistence_message, publish_error_message(reason))}

      nil ->
        {:noreply,
         socket
         |> assign(:draft_status, "No draft")
         |> assign(:persistence_message, "No draft spec is selected.")}
    end
  end

  defp normalize_workflow(nil) do
    %{id: "empty", name: "Untitled workflow", nodes: [], edges: []}
  end

  defp normalize_workflow(workflow) when is_map(workflow) do
    %{
      id: workflow_id(workflow),
      name: Map.get(workflow, :name) || Map.get(workflow, "name") || "Workflow",
      nodes: Map.get(workflow, :nodes) || Map.get(workflow, "nodes") || [],
      edges: Map.get(workflow, :edges) || Map.get(workflow, "edges") || []
    }
  end

  defp select_workflow(workflows, nil), do: List.first(workflows)

  defp select_workflow(workflows, workflow_id) do
    Enum.find(workflows, &(workflow_id(&1) == workflow_id)) || List.first(workflows)
  end

  defp workflow_id(workflow) when is_map(workflow) do
    workflow |> value(:id, "workflow") |> to_string()
  end

  defp center_nodes([], _width, _height), do: []

  defp center_nodes(nodes, width, height) when width > 0 and height > 0 do
    {min_x, max_x} = nodes |> Enum.map(& &1.x) |> Enum.min_max()
    {min_y, max_y} = nodes |> Enum.map(& &1.y) |> Enum.min_max()

    graph_width = max_x - min_x + @node_width
    graph_height = max_y - min_y + @node_height
    target_x = max(div(width - graph_width, 2), @canvas_padding)
    target_y = max(div(height - graph_height, 2), @canvas_padding)
    offset_x = target_x - min_x
    offset_y = target_y - min_y

    Enum.map(nodes, fn node ->
      %{node | x: node.x + offset_x, y: node.y + offset_y}
    end)
  end

  defp center_nodes(nodes, _width, _height), do: nodes

  defp build_edges(edges, nodes) do
    node_lookup = Map.new(nodes, &{&1.id, &1})

    Enum.flat_map(edges, fn edge ->
      with {:ok, source} <- Map.fetch(node_lookup, edge.source),
           {:ok, target} <- Map.fetch(node_lookup, edge.target) do
        [
          edge
          |> Map.put(:path, edge_path(source, target))
          |> Map.put(:label_x, label_x(source, target))
          |> Map.put(:label_y, label_y(source, target))
        ]
      else
        :error -> []
      end
    end)
  end

  defp edge_path(source, target) do
    start_x = source.x + @node_width
    start_y = source.y + div(@node_height, 2)
    end_x = target.x
    end_y = target.y + div(@node_height, 2)
    curve = max(div(abs(end_x - start_x), 2), 80)

    "M #{start_x} #{start_y} C #{start_x + curve} #{start_y}, #{end_x - curve} #{end_y}, #{end_x} #{end_y}"
  end

  defp label_x(source, target), do: div(source.x + target.x + @node_width, 2)
  defp label_y(source, target), do: div(source.y + target.y + @node_height, 2)

  defp parse_coordinate(value) when is_integer(value), do: max(value, 0)
  defp parse_coordinate(value) when is_float(value), do: value |> round() |> max(0)

  defp parse_coordinate(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> max(integer, 0)
      :error -> 0
    end
  end

  defp parse_coordinate(_value), do: 0

  defp node_accessible_label(node, issue_count) do
    type = node.type |> to_string() |> String.replace("_", " ")

    suffix =
      if issue_count > 0 do
        ", #{issue_count} validation #{if(issue_count == 1, do: "issue", else: "issues")}"
      else
        ""
      end

    "#{node.label}, #{type} node#{suffix}"
  end

  defp catalog_icon("built_in"), do: "built-in"
  defp catalog_icon(_provider), do: "step"

  defp catalog_entry_available?(entry) do
    Map.get(entry, "enabled", true) and Map.get(entry, "authorized", true)
  end

  defp catalog_disabled_reason(entry) do
    Map.get(entry, "disabled_reason") || "host policy does not allow this connector"
  end

  defp catalog_message(nil), do: "Host-approved connector actions."
  defp catalog_message(error), do: resource_error_message(:connector_actions, error)

  defp assign_catalog_groups(socket) do
    filtered_entries =
      socket.assigns.connector_catalog
      |> ConnectorCatalog.filter_by_query(socket.assigns.catalog_query)

    assign(socket, :catalog_groups, ConnectorCatalog.group_by_category(filtered_entries))
  end

  defp catalog_form(query), do: to_form(%{"q" => query}, as: :catalog_filter)

  defp find_catalog_entry(entries, provider, action_key) do
    Enum.find(entries, fn entry ->
      Map.get(entry, "action_key") == action_key and
        (is_nil(provider) or Map.get(entry, "provider") == provider)
    end)
  end

  defp catalog_entry_to_node(entry, index) do
    provider = Map.fetch!(entry, "provider")
    action_key = Map.fetch!(entry, "action_key")

    %{
      id: "#{provider}-#{action_key}-#{index}",
      label: Map.fetch!(entry, "display_name"),
      type: "action",
      icon: "hero-bolt",
      x: 80 + index * 24,
      y: 120 + index * 18
    }
  end

  defp assign_spec_view(socket) do
    draft = selected_draft(socket)
    spec = current_spec(draft, socket.assigns.workflow)
    validation_errors = spec_validation_errors(draft)

    {annotated_errors, node_validation_counts, edge_validation_counts} =
      validation_annotations(validation_errors, spec, socket.assigns.edges)

    socket
    |> assign(:spec_json, Jason.encode!(spec, pretty: true))
    |> assign(:spec_validation_errors, annotated_errors)
    |> assign(:node_validation_counts, node_validation_counts)
    |> assign(:edge_validation_counts, edge_validation_counts)
  end

  defp current_spec(nil, workflow) do
    Drafts.spec_from_workflow(workflow)
  end

  defp current_spec(draft, _workflow) do
    Map.get(draft, "spec", %{})
  end

  defp spec_validation_errors(nil), do: []

  defp spec_validation_errors(draft) do
    draft
    |> Map.get("validation_errors", [])
    |> Enum.map(&normalize_validation_error/1)
  end

  defp normalize_validation_error(error) do
    path_segments =
      error
      |> value(:path, [])
      |> List.wrap()
      |> Enum.map(&to_string/1)

    %{
      path: Enum.join(path_segments, "."),
      path_segments: path_segments,
      message: value(error, :message, "Validation issue")
    }
  end

  defp draft_validation_errors(errors) do
    Enum.map(errors, fn error ->
      %{
        "path" => error |> value(:path, []) |> List.wrap() |> Enum.map(&to_string/1),
        "message" => value(error, :message, "Validation issue")
      }
    end)
  end

  defp validation_annotations(errors, spec, edges) do
    steps = Map.get(spec, "steps", [])
    transitions = Map.get(spec, "transitions", [])
    edge_lookup = Map.new(edges, &{{&1.source, &1.target}, &1.id})

    Enum.reduce(errors, {[], %{}, %{}}, fn error, {annotated_errors, node_counts, edge_counts} ->
      case validation_anchor(error, steps, transitions, edge_lookup) do
        {:node, node_id} ->
          {
            annotated_errors ++ [Map.put(error, :anchor, %{kind: "node", id: node_id})],
            Map.update(node_counts, node_id, 1, &(&1 + 1)),
            edge_counts
          }

        {:edge, edge_id} ->
          {
            annotated_errors ++ [Map.put(error, :anchor, %{kind: "edge", id: edge_id})],
            node_counts,
            Map.update(edge_counts, edge_id, 1, &(&1 + 1))
          }

        :global ->
          {annotated_errors ++ [error], node_counts, edge_counts}
      end
    end)
  end

  defp validation_anchor(%{path_segments: ["steps", index | _rest]}, steps, _transitions, _edges) do
    with {index, ""} <- Integer.parse(index),
         step when is_map(step) <- Enum.at(steps, index),
         name when is_binary(name) <- value(step, :name) do
      {:node, name}
    else
      _other -> :global
    end
  end

  defp validation_anchor(
         %{path_segments: ["transitions", index | _rest]},
         _steps,
         transitions,
         edge_lookup
       ) do
    with {index, ""} <- Integer.parse(index),
         transition when is_map(transition) <- Enum.at(transitions, index),
         from when is_binary(from) <- value(transition, :from),
         to when is_binary(to) <- value(transition, :to),
         edge_id when is_binary(edge_id) <- Map.get(edge_lookup, {from, to}) do
      {:edge, edge_id}
    else
      _other -> :global
    end
  end

  defp validation_anchor(_error, _steps, _transitions, _edge_lookup), do: :global

  defp initialize_validation_feedback(socket) do
    errors = socket.assigns.spec_validation_errors

    socket
    |> assign(:validation_checked?, false)
    |> assign(
      :validation_status,
      if(errors == [], do: "Not validated", else: "Validation issues")
    )
    |> assign(
      :validation_message,
      if(errors == [],
        do: "Run validation before publishing or starting a workflow.",
        else: validation_issue_message(errors)
      )
    )
  end

  defp assign_validation_result(socket, :ok) do
    socket
    |> assign(:validation_checked?, true)
    |> assign(:validation_status, "Valid draft")
    |> assign(:validation_message, "Draft passes Squidie editor validation.")
  end

  defp assign_validation_result(socket, {:error, errors}) do
    socket
    |> assign(:validation_checked?, true)
    |> assign(:validation_status, "Validation issues")
    |> assign(:validation_message, validation_issue_message(errors))
  end

  defp validation_issue_message(errors) when is_list(errors) do
    count = length(errors)
    noun = if count == 1, do: "issue", else: "issues"
    "#{count} validation #{noun} found."
  end

  defp validation_badge_class("Valid draft"), do: "success"
  defp validation_badge_class("Not validated"), do: "neutral"
  defp validation_badge_class("No draft"), do: "neutral"
  defp validation_badge_class(_status), do: "warn"

  defp deny_draft_mutation(socket) do
    socket
    |> assign(:persistence_message, "Read-only access cannot change drafts.")
    |> assign(:catalog_message, "Read-only access cannot change drafts.")
  end

  defp normalize_theme("system"), do: :system
  defp normalize_theme("light"), do: :light
  defp normalize_theme("dark"), do: :dark
  defp normalize_theme(_theme), do: :system

  defp normalize_surface("spec"), do: :spec
  defp normalize_surface("visual"), do: :visual
  defp normalize_surface(:spec), do: :spec
  defp normalize_surface(:visual), do: :visual
  defp normalize_surface(_surface), do: :visual

  defp selected_draft(socket) do
    Enum.find(socket.assigns.drafts, &(Map.get(&1, "id") == socket.assigns.selected_draft_id))
  end

  defp update_selected_draft_spec(socket, updater) when is_function(updater, 1) do
    case selected_draft(socket) do
      nil ->
        socket

      draft ->
        updated_draft =
          draft
          |> Map.put("spec", updater.(Map.get(draft, "spec", %{})))
          |> Map.put("validation_errors", [])

        refresh_saved_draft(socket, updated_draft)
    end
  end

  defp assign_selected_graph(socket, selected_node_id \\ nil) do
    graph = selected_graph(socket)
    nodes = graph.nodes
    edges = build_edges(graph.edges, nodes)

    socket
    |> assign(:nodes, nodes)
    |> assign(:edges, edges)
    |> assign(:selected_node_id, resolve_selected_node_id(socket, nodes, selected_node_id))
    |> assign(:selected_edge_id, resolve_selected_edge_id(socket, edges))
  end

  defp selected_graph(socket) do
    case selected_draft(socket) do
      nil ->
        EditorGraph.build_from_workflow(socket.assigns.workflow)

      draft ->
        EditorGraph.build_from_spec(Map.get(draft, "spec", %{}), socket.assigns.workflow)
    end
  end

  defp resolve_selected_node_id(socket, nodes, selected_node_id) do
    cond do
      present_node?(nodes, selected_node_id) -> selected_node_id
      present_node?(nodes, socket.assigns.selected_node_id) -> socket.assigns.selected_node_id
      true -> nodes |> List.first(%{}) |> Map.get(:id)
    end
  end

  defp resolve_selected_edge_id(socket, edges) do
    if present_edge?(edges, socket.assigns.selected_edge_id) do
      socket.assigns.selected_edge_id
    else
      nil
    end
  end

  defp present_node?(nodes, node_id),
    do: is_binary(node_id) and Enum.any?(nodes, &(&1.id == node_id))

  defp present_edge?(edges, edge_id),
    do: is_binary(edge_id) and Enum.any?(edges, &(&1.id == edge_id))

  defp refresh_saved_draft(socket, draft) when is_map(draft) do
    id = Map.get(draft, "id") || socket.assigns.selected_draft_id
    drafts = Enum.map(socket.assigns.drafts, &if(Map.get(&1, "id") == id, do: draft, else: &1))

    socket
    |> assign(:drafts, drafts)
    |> assign(:selected_draft_id, id)
  end

  defp refresh_saved_draft(socket, _draft), do: socket

  defp draft_id(nil), do: nil
  defp draft_id(draft), do: Map.get(draft, "id")

  defp draft_status(error, _draft) when not is_nil(error), do: draft_error_status(error)
  defp draft_status(_error, nil), do: "No draft"

  defp draft_status(_error, draft),
    do: Map.get(draft, "definition_version", "draft") |> status_label()

  defp status_label("draft"), do: "Draft spec"
  defp status_label(status), do: String.capitalize(to_string(status))

  defp persistence_message(error, _draft) when not is_nil(error) do
    resource_error_message(:draft_access, error)
  end

  defp persistence_message(_error, nil) do
    "Host resolver has not exposed draft specs yet."
  end

  defp persistence_message(_error, _draft) do
    "Host persistence owns save, delete, and publish callbacks."
  end

  defp draft_error_status(:unauthorized), do: "Unauthorized"
  defp draft_error_status(:unsupported_capability), do: "Unavailable"
  defp draft_error_status(_reason), do: "Unavailable"

  defp save_error_message(:persistence_not_configured),
    do: "Draft was kept in the editor. Host save support is not available."

  defp save_error_message(reason),
    do: "Draft was kept in the editor. " <> resource_error_message(:save_support, reason)

  defp publish_error_message(:publish_not_configured),
    do: "Publish handoff failed. Host publish support is not available."

  defp publish_error_message(reason),
    do: "Publish handoff failed. " <> resource_error_message(:publish_support, reason)

  defp workflow_state_title(error, _workflow) when not is_nil(error), do: "Workflow unavailable."
  defp workflow_state_title(_error, %{nodes: []}), do: "Workflow unavailable."
  defp workflow_state_title(_error, _workflow), do: nil

  defp workflow_state_message(error, _workflow) when not is_nil(error),
    do: resource_error_message(:workflow_data, error)

  defp workflow_state_message(_error, %{nodes: []}),
    do: "Host has not exposed this workflow yet."

  defp workflow_state_message(_error, _workflow), do: nil

  defp resource_error_message(:draft_access, :unauthorized),
    do: "Host did not authorize draft access."

  defp resource_error_message(:connector_actions, :unsupported_capability),
    do: "Host has not enabled connector actions."

  defp resource_error_message(:save_support, :unsupported_capability),
    do: "Host save support is not available."

  defp resource_error_message(:publish_support, :unsupported_capability),
    do: "Host publish support is not available."

  defp resource_error_message(:workflow_data, :invalid_workflow_data),
    do: "Host workflow data is temporarily unavailable."

  defp resource_error_message(_resource, :resolver_failed),
    do: "Host workflow data is temporarily unavailable."

  defp resource_error_message(_resource, :invalid_draft_data),
    do: "Host draft data is temporarily unavailable."

  defp resource_error_message(_resource, :invalid_connector_catalog),
    do: "Host connector data is temporarily unavailable."

  defp resource_error_message(:workflow_data, :unauthorized),
    do: "Host did not authorize workflow access."

  defp resource_error_message(:connector_actions, :unauthorized),
    do: "Host did not authorize connector access."

  defp resource_error_message(:save_support, _reason), do: "Host save support is not available."

  defp resource_error_message(:publish_support, _reason),
    do: "Host publish support is not available."

  defp resource_error_message(:workflow_data, _reason),
    do: "Host workflow data is temporarily unavailable."

  defp resource_error_message(:draft_access, _reason),
    do: "Host draft data is temporarily unavailable."

  defp resource_error_message(:connector_actions, _reason),
    do: "Host connector data is temporarily unavailable."

  defp value(map, key, default \\ nil)
  defp value(map, key, default), do: Map.get(map, key) || Map.get(map, to_string(key)) || default
end
