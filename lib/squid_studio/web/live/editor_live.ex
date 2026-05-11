defmodule SquidStudio.Web.EditorLive do
  @moduledoc false

  use SquidStudio.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    workflow = socket.assigns.workflows |> List.wrap() |> List.first() |> normalize_workflow()
    graph = build_graph(workflow.nodes, workflow.edges)

    socket =
      socket
      |> assign(:page_title, "Editor")
      |> assign(:workflow, workflow)
      |> assign(:nodes, graph.nodes)
      |> assign(:edges, graph.edges)
      |> assign(:selected_node_id, graph.nodes |> List.first(%{}) |> Map.get(:id))

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

  def handle_event("select_node", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_node_id, id)}
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
    start_x = source.x + 160
    start_y = source.y + 32
    end_x = target.x
    end_y = target.y + 32
    curve = max(div(abs(end_x - start_x), 2), 80)

    "M #{start_x} #{start_y} C #{start_x + curve} #{start_y}, #{end_x - curve} #{end_y}, #{end_x} #{end_y}"
  end

  defp label_x(source, target), do: div(source.x + target.x + 160, 2)
  defp label_y(source, target), do: div(source.y + target.y + 64, 2)

  defp parse_coordinate(value) when is_integer(value), do: max(value, 0)
  defp parse_coordinate(value) when is_float(value), do: value |> round() |> max(0)

  defp parse_coordinate(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> max(integer, 0)
      :error -> 0
    end
  end

  defp parse_coordinate(_value), do: 0

  defp value(map, key, default \\ nil)
  defp value(map, key, default), do: Map.get(map, key) || Map.get(map, to_string(key)) || default
end
