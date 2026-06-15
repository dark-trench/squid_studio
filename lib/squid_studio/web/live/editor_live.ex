defmodule SquidStudio.Web.EditorLive do
  @moduledoc false

  use SquidStudio.Web, :live_view

  alias SquidStudio.ConnectorCatalog
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

    graph = build_graph(workflow.nodes, workflow.edges)
    drafts = List.wrap(socket.assigns[:drafts])
    selected_draft = List.first(drafts)
    connector_catalog = List.wrap(socket.assigns[:connector_catalog])

    socket =
      socket
      |> assign(:page_title, "Editor")
      |> assign(:workflow, workflow)
      |> assign(:drafts, drafts)
      |> assign(:selected_draft_id, draft_id(selected_draft))
      |> assign(:draft_status, draft_status(socket.assigns[:draft_error], selected_draft))
      |> assign(
        :persistence_message,
        persistence_message(socket.assigns[:draft_error], selected_draft)
      )
      |> assign(:nodes, graph.nodes)
      |> assign(:edges, graph.edges)
      |> assign(:connector_catalog, connector_catalog)
      |> assign(:catalog_groups, ConnectorCatalog.group_by_category(connector_catalog))
      |> assign(:catalog_message, catalog_message(socket.assigns[:connector_catalog_error]))
      |> assign(:graph_centered?, false)
      |> assign(:selected_node_id, graph.nodes |> List.first(%{}) |> Map.get(:id))
      |> assign(:theme, :system)

    {:ok, socket}
  end

  @impl true
  def handle_event("move_node", %{"id" => id, "x" => x, "y" => y}, socket) do
    nodes =
      Enum.map(socket.assigns.nodes, fn
        %{id: ^id} = node -> %{node | x: parse_coordinate(x), y: parse_coordinate(y)}
        node -> node
      end)

    {:noreply, assign(socket, nodes: nodes, edges: build_edges(socket.assigns.edges, nodes))}
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
    {:noreply, assign(socket, :selected_node_id, id)}
  end

  def handle_event("set_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, normalize_theme(theme))}
  end

  def handle_event("select_draft", %{"id" => id}, socket) do
    draft = Enum.find(socket.assigns.drafts, &(Map.get(&1, "id") == id))

    {:noreply,
     socket
     |> assign(:selected_draft_id, id)
     |> assign(:draft_status, draft_status(nil, draft))
     |> assign(:persistence_message, persistence_message(nil, draft))}
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
        nodes = socket.assigns.nodes ++ [node]

        {:noreply,
         socket
         |> assign(:nodes, nodes)
         |> assign(:edges, build_edges(socket.assigns.edges, nodes))
         |> assign(:selected_node_id, node.id)
         |> assign(:drafts, add_node_to_selected_draft(socket, node, connector))
         |> assign(
           :catalog_message,
           "#{Map.fetch!(connector, "display_name")} added to the draft."
         )}
    end
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
         |> assign(:persistence_message, "Host persistence accepted the draft spec.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:draft_status, "Unsaved")
         |> assign(:persistence_message, error_message("Draft was kept in the editor", reason))}

      nil ->
        {:noreply,
         socket
         |> assign(:draft_status, "No draft")
         |> assign(:persistence_message, "No draft spec is selected.")}
    end
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
         |> assign(:persistence_message, error_message("Publish handoff failed", reason))}

      nil ->
        {:noreply,
         socket
         |> assign(:draft_status, "No draft")
         |> assign(:persistence_message, "No draft spec is selected.")}
    end
  end

  defp build_graph(nodes, edges) do
    nodes = Enum.map(nodes, &normalize_node/1)

    %{
      nodes: nodes,
      edges: edges |> Enum.map(&normalize_edge/1) |> build_edges(nodes)
    }
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

  defp normalize_node(node) when is_map(node) do
    data = Map.get(node, :data) || Map.get(node, "data") || %{}
    position = Map.get(node, :position) || Map.get(node, "position") || %{}
    id = node |> value(:id) |> to_string()

    %{
      id: id,
      label: data |> value(:label, id) |> to_string(),
      type: node |> value(:type, "step") |> to_string(),
      icon: node |> value(:type, "step") |> to_string() |> node_icon(),
      x: position |> value(:x, 0) |> parse_coordinate(),
      y: position |> value(:y, 0) |> parse_coordinate()
    }
  end

  defp normalize_edge(edge) when is_map(edge) do
    source = edge |> value(:source) |> to_string()
    target = edge |> value(:target) |> to_string()

    %{
      id: edge |> value(:id, "#{source}-#{target}") |> to_string(),
      source: source,
      target: target
    }
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

  defp node_icon("trigger"), do: "hero-clock"
  defp node_icon("retry"), do: "hero-arrow-path"
  defp node_icon("failure"), do: "hero-exclamation-triangle"
  defp node_icon("terminal"), do: "hero-check-circle"
  defp node_icon("approval"), do: "hero-hand-raised"
  defp node_icon("wait"), do: "hero-pause-circle"
  defp node_icon("built_in"), do: "hero-cube"
  defp node_icon("input"), do: "hero-arrow-down-tray"
  defp node_icon("output"), do: "hero-paper-airplane"
  defp node_icon(_type), do: "hero-bolt"

  defp catalog_icon("built_in"), do: "built-in"
  defp catalog_icon(_provider), do: "step"

  defp catalog_entry_available?(entry) do
    Map.get(entry, "enabled", true) and Map.get(entry, "authorized", true)
  end

  defp catalog_disabled_reason(entry) do
    Map.get(entry, "disabled_reason") || "host policy does not allow this connector"
  end

  defp catalog_message(nil), do: "Host-approved connector actions."

  defp catalog_message(error),
    do: error_message("Host connector catalog returned invalid data", error)

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
      icon: node_icon("action"),
      x: 80 + index * 24,
      y: 120 + index * 18
    }
  end

  defp add_node_to_selected_draft(socket, node, connector) do
    Enum.map(socket.assigns.drafts, fn draft ->
      if Map.get(draft, "id") == socket.assigns.selected_draft_id do
        add_node_to_draft(draft, node, connector)
      else
        draft
      end
    end)
  end

  defp add_node_to_draft(draft, node, connector) do
    spec = Map.get(draft, "spec", %{})
    nodes = Map.get(spec, "nodes", [])

    connector_node = %{
      "id" => node.id,
      "type" => "action",
      "data" => %{
        "label" => node.label,
        "provider" => Map.get(connector, "provider"),
        "action_key" => Map.get(connector, "action_key"),
        "input_contract" => Map.get(connector, "input_contract"),
        "output_contract" => Map.get(connector, "output_contract"),
        "credential_requirements" => Map.get(connector, "credential_requirements")
      }
    }

    Map.put(draft, "spec", Map.put(spec, "nodes", nodes ++ [connector_node]))
  end

  defp normalize_theme("system"), do: :system
  defp normalize_theme("light"), do: :light
  defp normalize_theme("dark"), do: :dark
  defp normalize_theme(_theme), do: :system

  defp selected_draft(socket) do
    Enum.find(socket.assigns.drafts, &(Map.get(&1, "id") == socket.assigns.selected_draft_id))
  end

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

  defp draft_status(error, _draft) when not is_nil(error), do: "Persistence error"
  defp draft_status(_error, nil), do: "No draft"

  defp draft_status(_error, draft),
    do: Map.get(draft, "definition_version", "draft") |> status_label()

  defp status_label("draft"), do: "Draft spec"
  defp status_label(status), do: String.capitalize(to_string(status))

  defp persistence_message(error, _draft) when not is_nil(error) do
    error_message("Host draft resolver returned invalid data", error)
  end

  defp persistence_message(_error, nil) do
    "Host resolver has not exposed draft specs yet."
  end

  defp persistence_message(_error, _draft) do
    "Host persistence owns save, delete, and publish callbacks."
  end

  defp error_message(prefix, reason), do: "#{prefix}: #{inspect(reason)}"

  defp value(map, key, default \\ nil)
  defp value(map, key, default), do: Map.get(map, key) || Map.get(map, to_string(key)) || default
end
