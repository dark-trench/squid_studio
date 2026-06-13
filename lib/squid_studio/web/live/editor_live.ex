defmodule SquidStudio.Web.EditorLive do
  @moduledoc false

  use SquidStudio.Web, :live_view

  alias SquidStudio.Web.Resolver

  @node_width 160
  @node_height 76
  @canvas_padding 40

  @impl true
  def mount(_params, _session, socket) do
    workflow = socket.assigns.workflows |> List.wrap() |> List.first() |> normalize_workflow()
    graph = build_graph(workflow.nodes, workflow.edges)
    drafts = List.wrap(socket.assigns[:drafts])
    selected_draft = List.first(drafts)

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
      id: Map.get(workflow, :id) || Map.get(workflow, "id") || "workflow",
      name: Map.get(workflow, :name) || Map.get(workflow, "name") || "Workflow",
      nodes: Map.get(workflow, :nodes) || Map.get(workflow, "nodes") || [],
      edges: Map.get(workflow, :edges) || Map.get(workflow, "edges") || []
    }
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
