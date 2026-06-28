defmodule SquidStudio.Web.EditorLive do
  @moduledoc false

  use SquidStudio.Web, :live_view

  alias Squidie.Workflow.EditorSpec
  alias SquidStudio.ActionRegistryValidation
  alias SquidStudio.ConnectorCatalog
  alias SquidStudio.Drafts
  alias SquidStudio.EditorGraph
  alias SquidStudio.Web.Resolver

  @node_width 160
  @node_height 76
  @canvas_padding 40
  @step_key_pattern ~r/^[a-z][a-z0-9_]*$/
  @step_property_boolean_fields ["irreversible", "compensatable"]

  @impl true
  def mount(params, _session, socket) do
    workflows =
      socket.assigns.workflows
      |> List.wrap()
      |> Enum.map(&normalize_workflow/1)

    draft_inventory = List.wrap(socket.assigns[:drafts])
    connector_catalog = List.wrap(socket.assigns[:connector_catalog])
    catalog_query = ""

    socket =
      socket
      |> assign(:page_title, "Editor")
      |> assign(:read_only?, socket.assigns.access == :read_only)
      |> assign(:editor_surface, :visual)
      |> assign(:workflow_inventory, workflows)
      |> assign(:workflow_items, [])
      |> assign(:workflow, normalize_workflow(nil))
      |> assign(:selected_workflow_id, nil)
      |> assign(:draft_inventory, draft_inventory)
      |> assign(:drafts, [])
      |> assign(:selected_draft_id, nil)
      |> assign(:draft_dirty?, false)
      |> assign(:draft_status, "No draft")
      |> assign(:persistence_message, persistence_message(socket.assigns[:draft_error], nil))
      |> assign(:nodes, [])
      |> assign(:edges, [])
      |> assign(:connector_catalog, connector_catalog)
      |> assign(:catalog_query, catalog_query)
      |> assign(:catalog_form, catalog_form(catalog_query))
      |> assign(:catalog_message, catalog_message(socket.assigns[:connector_catalog_error]))
      |> assign(:graph_centered?, false)
      |> assign(:selected_node_id, nil)
      |> assign(:selected_edge_id, nil)
      |> assign(:selected_step, nil)
      |> assign(:step_property_values, %{})
      |> assign(:step_property_errors, %{})
      |> assign(:step_properties_form, step_properties_form(%{}))
      |> assign(:theme, :system)
      |> assign(:validation_checked?, false)
      |> select_workflow_state(params["workflow_id"])
      |> assign_catalog_groups()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, select_workflow_state(socket, params["workflow_id"])}
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

    {:noreply, mark_draft_dirty(socket)}
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
    {:noreply, select_node(socket, id)}
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
     |> select_node(id)}
  end

  def handle_event(
        "focus_validation_issue",
        %{"anchor_kind" => "edge", "anchor_id" => id},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:editor_surface, :visual)
     |> select_edge(id)}
  end

  def handle_event("set_editor_surface", %{"surface" => surface}, socket) do
    {:noreply, assign(socket, :editor_surface, normalize_surface(surface))}
  end

  def handle_event("change_step_properties", _params, %{assigns: %{read_only?: true}} = socket) do
    {:noreply, deny_draft_mutation(socket)}
  end

  def handle_event("change_step_properties", %{"step_properties" => params}, socket) do
    values =
      socket.assigns.step_property_values
      |> Map.merge(normalize_step_property_params(params))
      |> normalize_step_property_values()

    errors = validate_step_properties(socket, values)

    socket =
      if errors == %{} do
        connector = step_property_connector(socket, values)
        selected_step_name = value(socket.assigns.selected_step || %{}, :name, "")

        socket
        |> update_selected_draft_spec(fn spec ->
          EditorGraph.update_step_properties(spec, selected_step_name, values, connector)
        end)
        |> assign_selected_graph(Map.get(values, "name"))
        |> assign_spec_view()
        |> initialize_validation_feedback()
        |> mark_draft_dirty()
      else
        assign_step_properties_state(socket, values, errors)
      end

    {:noreply, socket}
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
    if step_property_errors?(socket) do
      {:noreply,
       socket
       |> assign(:validation_checked?, true)
       |> assign(:validation_status, "Validation issues")
       |> assign(:validation_message, "Fix step property errors before validating.")}
    else
      case selected_draft(socket) do
        nil ->
          {:noreply,
           socket
           |> assign(:validation_checked?, true)
           |> assign(:validation_status, "No draft")
           |> assign(:validation_message, "No draft spec is selected.")}

        draft ->
          {:noreply, validate_selected_draft(socket, draft)}
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
     |> clear_draft_dirty()
     |> assign_selected_graph()
     |> assign_spec_view()
     |> initialize_validation_feedback()}
  end

  def handle_event("add_catalog_node", _params, %{assigns: %{read_only?: true}} = socket) do
    {:noreply, deny_draft_mutation(socket)}
  end

  def handle_event("add_catalog_node", %{"action_key" => action_key} = params, socket) do
    {:noreply, insert_catalog_node(socket, params["provider"], action_key, params)}
  end

  def handle_event("drop_catalog_node", _params, %{assigns: %{read_only?: true}} = socket) do
    {:noreply, deny_draft_mutation(socket)}
  end

  def handle_event("drop_catalog_node", %{"action_key" => action_key} = params, socket) do
    {:noreply, insert_catalog_node(socket, params["provider"], action_key, params)}
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
        saved_draft = preserve_validation_errors(saved_draft, draft)

        {:noreply,
         socket
         |> refresh_saved_draft(saved_draft)
         |> clear_draft_dirty()
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
    spec = current_spec(draft, socket.assigns.workflow)
    registry_errors = ActionRegistryValidation.validate(spec, socket.assigns.connector_catalog)

    cond do
      step_property_errors?(socket) ->
        {:noreply,
         socket
         |> assign(:draft_status, "Draft spec")
         |> assign(:persistence_message, "Fix step property errors before publishing.")}

      is_nil(draft) ->
        {:noreply,
         socket
         |> assign(:draft_status, "No draft")
         |> assign(:persistence_message, "No draft spec is selected.")}

      registry_errors != [] ->
        {:noreply,
         socket
         |> refresh_saved_draft(
           Map.put(draft, "validation_errors", registry_errors),
           preserve_graph?: true
         )
         |> assign_spec_view()
         |> focus_first_validation_anchor()
         |> assign_validation_result({:error, registry_errors})
         |> assign(:draft_status, "Draft spec")
         |> assign(:persistence_message, "Publish blocked until validation issues are resolved.")}

      true ->
        case Resolver.call_with_fallback(socket.assigns.resolver, :publish_draft, [
               socket.assigns.user,
               Map.get(draft, "id")
             ]) do
          {:ok, _version} ->
            {:noreply,
             socket
             |> assign(:draft_status, "Published")
             |> assign(
               :persistence_message,
               "Host published a runnable Squidie workflow version."
             )}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:draft_status, "Draft spec")
             |> assign(:persistence_message, publish_error_message(reason))}
        end
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

  defp drafts_for_workflow(drafts, workflow_id) do
    Enum.filter(drafts, &(Map.get(&1, "workflow") == workflow_id))
  end

  defp resolve_selected_draft_id(draft_inventory, workflow_id, selected_draft_id) do
    if Enum.any?(draft_inventory, &(Map.get(&1, "id") == selected_draft_id)) do
      selected_draft_id
    else
      draft_inventory
      |> Enum.find(&(Map.get(&1, "workflow") == workflow_id))
      |> draft_id()
    end
  end

  defp workflow_sidebar_items(workflows, draft_inventory, read_only?) do
    Enum.map(workflows, fn workflow ->
      workflow_id = workflow.id
      draft_count = drafts_for_workflow(draft_inventory, workflow_id) |> length()

      %{
        id: workflow_id,
        name: workflow.name,
        draft_count: draft_count,
        badges: workflow_badges(draft_count, read_only?)
      }
    end)
  end

  defp workflow_badges(draft_count, read_only?) do
    base_badges = if draft_count > 0, do: ["Draft spec"], else: ["Published"]

    if read_only? do
      base_badges ++ ["Read-only"]
    else
      base_badges
    end
  end

  defp workflow_badge_class("Published"), do: "success"
  defp workflow_badge_class("Read-only"), do: "neutral"
  defp workflow_badge_class(_badge), do: "warn"

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

  defp catalog_entry_to_node(entry, index, params) do
    provider = Map.fetch!(entry, "provider")
    action_key = Map.fetch!(entry, "action_key")
    x = Map.get(params, "x", 80 + index * 24) |> parse_coordinate()
    y = Map.get(params, "y", 120 + index * 18) |> parse_coordinate()

    %{
      id: "#{provider}-#{action_key}-#{index}",
      label: Map.fetch!(entry, "display_name"),
      type: "action",
      icon: "hero-bolt",
      x: x,
      y: y
    }
  end

  defp insert_catalog_node(socket, provider, action_key, params) do
    connector = find_catalog_entry(socket.assigns.connector_catalog, provider, action_key)

    cond do
      is_nil(connector) ->
        assign(socket, :catalog_message, "Connector unavailable.")

      not catalog_entry_available?(connector) ->
        assign(
          socket,
          :catalog_message,
          "Connector unavailable: #{catalog_disabled_reason(connector)}"
        )

      true ->
        node = catalog_entry_to_node(connector, length(socket.assigns.nodes), params)

        socket
        |> update_selected_draft_spec(&EditorGraph.add_action_step(&1, node, connector))
        |> assign_selected_graph(node.id)
        |> assign(:selected_edge_id, nil)
        |> assign_spec_view()
        |> initialize_validation_feedback()
        |> mark_draft_dirty()
        |> assign(
          :catalog_message,
          "#{Map.fetch!(connector, "display_name")} added to the draft."
        )
    end
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

  defp validate_selected_draft(socket, draft) do
    spec = current_spec(draft, socket.assigns.workflow)
    errors = validate_draft_spec(spec, socket.assigns.connector_catalog)

    socket =
      socket
      |> refresh_saved_draft(
        Map.put(draft, "validation_errors", errors),
        preserve_graph?: true
      )
      |> assign_spec_view()

    if errors == [] do
      assign_validation_result(socket, :ok)
    else
      socket
      |> focus_first_validation_anchor()
      |> assign_validation_result({:error, errors})
    end
  end

  defp validate_draft_spec(spec, connector_catalog) do
    editor_errors =
      case EditorSpec.validate_map(spec) do
        :ok -> []
        {:error, {:invalid_workflow_editor_spec, errors}} -> draft_validation_errors(errors)
      end

    editor_errors ++ ActionRegistryValidation.validate(spec, connector_catalog)
  end

  defp focus_first_validation_anchor(socket) do
    case Enum.find(socket.assigns.spec_validation_errors, &Map.has_key?(&1, :anchor)) do
      %{anchor: %{kind: "node", id: id}} ->
        select_node(socket, id)

      %{anchor: %{kind: "edge", id: id}} ->
        select_edge(socket, id)

      _other ->
        socket
    end
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

  defp select_workflow_state(socket, workflow_id, selected_draft_id \\ nil) do
    workflow =
      socket.assigns.workflow_inventory
      |> select_workflow(workflow_id)
      |> normalize_workflow()

    selected_draft_id =
      resolve_selected_draft_id(
        socket.assigns.draft_inventory,
        workflow.id,
        selected_draft_id
      )

    selected_draft =
      Enum.find(socket.assigns.draft_inventory, &(Map.get(&1, "id") == selected_draft_id))

    socket
    |> assign(:workflow, workflow)
    |> assign(:selected_workflow_id, workflow.id)
    |> assign(
      :workflow_items,
      workflow_sidebar_items(
        socket.assigns.workflow_inventory,
        socket.assigns.draft_inventory,
        socket.assigns.read_only?
      )
    )
    |> assign(:drafts, socket.assigns.draft_inventory)
    |> assign(:selected_draft_id, selected_draft_id)
    |> clear_draft_dirty()
    |> assign(:draft_status, draft_status(socket.assigns[:draft_error], selected_draft))
    |> assign(
      :persistence_message,
      persistence_message(socket.assigns[:draft_error], selected_draft)
    )
    |> assign(:graph_centered?, false)
    |> assign_selected_graph()
    |> assign_spec_view()
    |> initialize_validation_feedback()
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
    selected_node_id = resolve_selected_node_id(socket, nodes, selected_node_id)
    selected_edge_id = resolve_selected_edge_id(socket, edges)

    socket
    |> assign(:nodes, nodes)
    |> assign(:edges, edges)
    |> assign(:selected_node_id, selected_node_id)
    |> assign(:selected_edge_id, selected_edge_id)
    |> assign(:selected_step, selected_step(socket, selected_node_id))
    |> assign_step_properties_state()
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

  defp selected_step(socket, node_id) when is_binary(node_id) do
    socket
    |> selected_step_spec()
    |> Map.get("steps", [])
    |> List.wrap()
    |> Enum.find(&(value(&1, :name) == node_id))
  end

  defp selected_step(_socket, _node_id), do: nil

  defp selected_step_spec(socket) do
    current_spec(selected_draft(socket), socket.assigns.workflow)
  end

  defp selected_node(socket) do
    Enum.find(socket.assigns.nodes, &(&1.id == socket.assigns.selected_node_id))
  end

  defp current_step_property_values(%{assigns: %{selected_step: nil}}), do: %{}

  defp current_step_property_values(socket) do
    step = socket.assigns.selected_step
    node = selected_node(socket)
    opts = value(step, :opts, %{})
    retry = value(opts, :retry, %{})
    backoff = value(retry, :backoff, %{})
    metadata = value(step, :metadata, %{})

    %{
      "name" => value(step, :name, ""),
      "label" => node_label(node, step),
      "action" => value(step, :action, ""),
      "input_mapping" => serialize_input_mapping(value(opts, :input)),
      "output_key" => string_value(value(opts, :output)),
      "retry_max_attempts" => string_value(value(retry, :max_attempts)),
      "retry_backoff_min" => string_value(value(backoff, :min)),
      "retry_backoff_max" => string_value(value(backoff, :max)),
      "irreversible" => boolean_form_value(value(opts, :irreversible, false)),
      "compensatable" => boolean_form_value(compensatable_value(opts)),
      "notes" => string_value(value(metadata, :notes))
    }
  end

  defp node_label(nil, step), do: value(step, :name, "")
  defp node_label(node, _step), do: Map.get(node, :label, "")

  defp assign_step_properties_state(socket, values \\ nil, errors \\ %{}) do
    values = values || current_step_property_values(socket)

    socket
    |> assign(:step_property_values, values)
    |> assign(:step_property_errors, errors)
    |> assign(:step_properties_form, step_properties_form(values))
  end

  defp step_properties_form(values) do
    to_form(values, as: :step_properties)
  end

  defp normalize_step_property_params(params) when is_map(params) do
    params
    |> Map.new(fn {key, value} ->
      {to_string(key), value}
    end)
    |> normalize_boolean_step_property_params()
  end

  defp normalize_step_property_params(_params), do: %{}

  defp normalize_boolean_step_property_params(params) do
    Enum.reduce(@step_property_boolean_fields, params, fn field, acc ->
      Map.put_new(acc, field, "false")
    end)
  end

  defp normalize_step_property_values(values) when is_map(values) do
    Map.new(values, fn {key, value} ->
      {to_string(key), normalize_step_property_value(value)}
    end)
  end

  defp normalize_step_property_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_step_property_value(nil), do: ""
  defp normalize_step_property_value(value), do: to_string(value)

  defp validate_step_properties(%{assigns: %{selected_step: nil}}, _values), do: %{}

  defp validate_step_properties(socket, values) do
    errors = %{}
    selected_step_name = value(socket.assigns.selected_step || %{}, :name, "")
    name = Map.get(values, "name", "")
    label = Map.get(values, "label", "")

    errors =
      cond do
        name == "" ->
          Map.put(errors, "name", "Step name can't be blank.")

        duplicate_step_name?(socket, name, selected_step_name) ->
          Map.put(errors, "name", "Step name must be unique.")

        true ->
          errors
      end

    errors =
      if label == "" do
        Map.put(errors, "label", "Label can't be blank.")
      else
        errors
      end

    if action_step_selected?(socket) do
      action_key = Map.get(values, "action", "")

      errors =
        if available_connector(socket.assigns.connector_catalog, action_key) do
          errors
        else
          Map.put(errors, "action", "Action key is not available for this user.")
        end

      errors
    else
      errors
    end
    |> validate_input_mapping(values)
    |> validate_output_key(values)
    |> validate_retry(values)
    |> validate_recovery(values)
  end

  defp duplicate_step_name?(socket, name, selected_step_name) do
    socket
    |> selected_step_spec()
    |> Map.get("steps", [])
    |> List.wrap()
    |> Enum.reject(&(value(&1, :name, "") == selected_step_name))
    |> Enum.any?(&(value(&1, :name, "") == name))
  end

  defp action_step_selected?(socket) do
    case selected_node(socket) do
      %{type: "action"} -> true
      _other -> value(socket.assigns.selected_step || %{}, :action) not in [nil, ""]
    end
  end

  defp step_property_connector(socket, values) do
    if action_step_selected?(socket) do
      available_connector(socket.assigns.connector_catalog, Map.get(values, "action", ""))
    else
      nil
    end
  end

  defp available_connector(catalog, action_key) when is_binary(action_key) do
    Enum.find(catalog, fn entry ->
      Map.get(entry, "action_key") == action_key and catalog_entry_available?(entry)
    end)
  end

  defp available_connector(_catalog, _action_key), do: nil

  defp step_property_error(errors, field), do: Map.get(errors, field)

  defp step_property_errors?(socket), do: socket.assigns.step_property_errors != %{}

  defp contract_entries(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), to_string(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp contract_entries(_value), do: []

  defp credential_labels(requirements) when is_list(requirements) do
    requirements
    |> Enum.map(&value(&1, :label))
    |> Enum.filter(&is_binary/1)
  end

  defp credential_labels(_requirements), do: []

  defp option_entries(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), inspect(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp option_entries(_value), do: []

  defp validate_input_mapping(errors, values) do
    case parse_input_mapping(Map.get(values, "input_mapping", "")) do
      {:ok, _mapping} ->
        errors

      {:error, message} ->
        Map.put(errors, "input_mapping", message)
    end
  end

  defp validate_output_key(errors, values) do
    output_key = Map.get(values, "output_key", "")

    if output_key in [nil, ""] or String.match?(output_key, @step_key_pattern) do
      errors
    else
      Map.put(errors, "output_key", "Output key must use snake_case.")
    end
  end

  defp validate_retry(errors, values) do
    max_attempts = Map.get(values, "retry_max_attempts", "")
    min_delay = Map.get(values, "retry_backoff_min", "")
    max_delay = Map.get(values, "retry_backoff_max", "")

    if max_attempts == "" and min_delay == "" and max_delay == "" do
      errors
    else
      errors
      |> maybe_validate_retry_max_attempts(max_attempts)
      |> maybe_validate_retry_backoff(min_delay, max_delay)
    end
  end

  defp validate_recovery(errors, values) do
    if step_property_checked?(Map.get(values, "irreversible")) and
         step_property_checked?(Map.get(values, "compensatable")) do
      Map.put(errors, "recovery", "A step cannot be both irreversible and compensatable.")
    else
      errors
    end
  end

  defp parse_input_mapping(value) when value in [nil, ""], do: {:ok, nil}

  defp parse_input_mapping(value) when is_binary(value) do
    case input_mapping_lines(value) do
      [] ->
        {:ok, nil}

      lines ->
        parse_input_mapping_lines(lines)
    end
  end

  defp parse_input_mapping(_value), do: {:error, invalid_input_mapping_message()}

  defp input_mapping_lines(value) do
    value
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_input_mapping_lines(lines) do
    cond do
      Enum.all?(lines, &String.contains?(&1, "=")) ->
        parse_targeted_input_mapping(lines)

      Enum.all?(lines, &(not String.contains?(&1, "="))) ->
        parse_selected_input_mapping(lines)

      true ->
        {:error, invalid_input_mapping_message()}
    end
  end

  defp parse_targeted_input_mapping(lines) do
    Enum.reduce_while(lines, {:ok, %{}}, fn line, {:ok, acc} ->
      [target, path] = String.split(line, "=", parts: 2)

      with {:ok, target} <- parse_input_mapping_segment(target),
           false <- Map.has_key?(acc, target),
           {:ok, path_segments} <- parse_input_mapping_path(path) do
        {:cont, {:ok, Map.put(acc, target, path_segments)}}
      else
        :error -> {:halt, {:error, invalid_input_mapping_message()}}
        true -> {:halt, {:error, duplicate_input_mapping_message()}}
      end
    end)
  end

  defp parse_selected_input_mapping(lines) do
    Enum.reduce_while(lines, {:ok, []}, fn line, {:ok, acc} ->
      case parse_input_mapping_segment(line) do
        {:ok, segment} ->
          continue_selected_input_mapping(acc, segment)

        :error ->
          {:halt, {:error, invalid_input_mapping_message()}}
      end
    end)
    |> case do
      {:ok, segments} -> {:ok, Enum.reverse(segments)}
      {:error, _message} = error -> error
    end
  end

  defp continue_selected_input_mapping(acc, segment) do
    if segment in acc do
      {:halt, {:error, duplicate_input_mapping_message()}}
    else
      {:cont, {:ok, [segment | acc]}}
    end
  end

  defp parse_input_mapping_path(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.split(".", trim: true)
    |> parse_input_mapping_segments()
  end

  defp parse_input_mapping_segments(segments) do
    Enum.reduce_while(segments, {:ok, []}, fn segment, {:ok, acc} ->
      case parse_input_mapping_segment(segment) do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, []} -> :error
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      :error -> :error
    end
  end

  defp parse_input_mapping_segment(value) when is_binary(value) do
    value = String.trim(value)

    if value != "" and String.match?(value, @step_key_pattern) do
      {:ok, value}
    else
      :error
    end
  end

  defp parse_input_mapping_segment(_value), do: :error

  defp invalid_input_mapping_message do
    "Input mapping lines must use target=payload.path or a bare field name."
  end

  defp duplicate_input_mapping_message, do: "Input mapping targets must be unique."

  defp maybe_validate_retry_max_attempts(errors, value) do
    if positive_integer_string?(value) do
      errors
    else
      Map.put(errors, "retry_max_attempts", "Retry max attempts must be a positive integer.")
    end
  end

  defp maybe_validate_retry_backoff(errors, "", ""), do: errors

  defp maybe_validate_retry_backoff(errors, min_delay, max_delay) do
    errors =
      if positive_integer_string?(min_delay) do
        errors
      else
        Map.put(errors, "retry_backoff_min", "Retry backoff min must be a positive integer.")
      end

    errors =
      cond do
        not positive_integer_string?(max_delay) ->
          Map.put(errors, "retry_backoff_max", "Retry backoff max must be a positive integer.")

        positive_integer_string?(min_delay) and
            String.to_integer(max_delay) < String.to_integer(min_delay) ->
          Map.put(
            errors,
            "retry_backoff_max",
            "Retry backoff max must be greater than or equal to the minimum."
          )

        true ->
          errors
      end

    errors
  end

  defp positive_integer_string?(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> true
      _other -> false
    end
  end

  defp positive_integer_string?(_value), do: false

  defp step_property_checked?(value), do: value in [true, "true", "on"]

  defp serialize_input_mapping(nil), do: ""

  defp serialize_input_mapping(mapping) when is_map(mapping) do
    mapping
    |> Enum.map(fn {target, path} ->
      "#{target}=#{path |> List.wrap() |> Enum.map_join(".", &to_string/1)}"
    end)
    |> Enum.sort()
    |> Enum.join("\n")
  end

  defp serialize_input_mapping(mapping) when is_list(mapping) do
    mapping
    |> Enum.map_join("\n", &to_string/1)
  end

  defp serialize_input_mapping(_mapping), do: ""

  defp string_value(nil), do: ""
  defp string_value(value) when is_binary(value), do: value
  defp string_value(value), do: to_string(value)

  defp boolean_form_value(true), do: "true"
  defp boolean_form_value(_value), do: "false"

  defp compensatable_value(opts) do
    case value(opts, :compensatable) do
      nil -> not step_property_checked?(value(opts, :irreversible, false))
      value -> step_property_checked?(value)
    end
  end

  defp select_node(socket, node_id) do
    socket
    |> assign(:selected_node_id, node_id)
    |> assign(:selected_edge_id, nil)
    |> assign(:selected_step, selected_step(socket, node_id))
    |> assign_step_properties_state()
  end

  defp select_edge(socket, edge_id) do
    socket
    |> assign(:selected_edge_id, edge_id)
    |> assign(:selected_step, nil)
    |> assign_step_properties_state()
  end

  defp refresh_saved_draft(socket, draft, opts \\ [])

  defp refresh_saved_draft(socket, draft, opts) when is_map(draft) do
    id = Map.get(draft, "id") || socket.assigns.selected_draft_id
    workflow_id = Map.get(draft, "workflow") || socket.assigns.selected_workflow_id
    draft_inventory = upsert_draft(socket.assigns.draft_inventory, id, draft)

    if Keyword.get(opts, :preserve_graph?, false) do
      refresh_selected_draft(socket, draft_inventory, workflow_id, id)
    else
      socket
      |> assign(:draft_inventory, draft_inventory)
      |> select_workflow_state(workflow_id, id)
    end
  end

  defp refresh_saved_draft(socket, _draft, _opts), do: socket

  defp refresh_selected_draft(socket, draft_inventory, workflow_id, selected_draft_id) do
    selected_draft = Enum.find(draft_inventory, &(Map.get(&1, "id") == selected_draft_id))

    socket
    |> assign(:draft_inventory, draft_inventory)
    |> assign(
      :workflow_items,
      workflow_sidebar_items(
        socket.assigns.workflow_inventory,
        draft_inventory,
        socket.assigns.read_only?
      )
    )
    |> assign(:drafts, draft_inventory)
    |> assign(:selected_workflow_id, workflow_id)
    |> assign(:selected_draft_id, selected_draft_id)
    |> clear_draft_dirty()
    |> assign(:draft_status, draft_status(socket.assigns[:draft_error], selected_draft))
    |> assign(
      :persistence_message,
      persistence_message(socket.assigns[:draft_error], selected_draft)
    )
  end

  defp upsert_draft(draft_inventory, id, draft) do
    if Enum.any?(draft_inventory, &(Map.get(&1, "id") == id)) do
      Enum.map(draft_inventory, &replace_draft(&1, id, draft))
    else
      draft_inventory ++ [draft]
    end
  end

  defp preserve_validation_errors(saved_draft, original_draft)
       when is_map(saved_draft) and is_map(original_draft) do
    if Map.has_key?(saved_draft, "validation_errors") do
      saved_draft
    else
      case Map.get(original_draft, "validation_errors") do
        errors when is_list(errors) and errors != [] ->
          Map.put(saved_draft, "validation_errors", errors)

        _other ->
          saved_draft
      end
    end
  end

  defp preserve_validation_errors(saved_draft, _original_draft), do: saved_draft

  defp mark_draft_dirty(socket) do
    if is_nil(selected_draft(socket)) do
      socket
    else
      assign(socket, :draft_dirty?, true)
    end
  end

  defp clear_draft_dirty(socket), do: assign(socket, :draft_dirty?, false)

  defp replace_draft(existing, id, draft) do
    if Map.get(existing, "id") == id, do: draft, else: existing
  end

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
    "Host persistence owns save and publish callbacks."
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

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key) || Map.get(map, to_string(key)) || default

  defp value(_value, _key, default), do: default
end
