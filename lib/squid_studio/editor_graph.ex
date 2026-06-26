defmodule SquidStudio.EditorGraph do
  @moduledoc """
  Adapts Squidie editor specs into the graph shape rendered by Studio.

  Studio keeps draft editing on the JSON-safe editor-spec side of the
  boundary. This module reads and writes only editor-owned spec data.
  """

  alias Squidie.Workflow.EditorSpec

  @base_x 80
  @base_y 120
  @step_spacing_x 240
  @step_spacing_y 96
  @step_key_pattern ~r/^[a-z][a-z0-9_]*$/

  @type graph_node :: %{
          id: String.t(),
          label: String.t(),
          type: String.t(),
          icon: String.t(),
          x: integer(),
          y: integer()
        }

  @type edge :: %{
          id: String.t(),
          source: String.t(),
          target: String.t()
        }

  @type graph :: %{nodes: [graph_node()], edges: [edge()]}

  @spec build_from_spec(map(), map() | nil) :: graph()
  def build_from_spec(spec, workflow \\ nil) when is_map(spec) do
    workflow_nodes =
      workflow
      |> build_from_workflow()
      |> Map.get(:nodes, [])
      |> Map.new(&{&1.id, &1})

    editor_nodes = editor_nodes(spec)

    graph =
      case EditorSpec.preview_graph(spec) do
        {:ok, preview} -> preview
        {:error, _reason} -> previewless_graph(spec)
      end

    %{
      nodes: build_nodes(graph, editor_nodes, workflow_nodes),
      edges: build_edges(graph)
    }
  end

  @spec build_from_workflow(map() | nil) :: graph()
  def build_from_workflow(nil), do: %{nodes: [], edges: []}

  def build_from_workflow(workflow) when is_map(workflow) do
    %{
      nodes:
        workflow
        |> value(:nodes, [])
        |> List.wrap()
        |> Enum.map(&workflow_node/1),
      edges:
        workflow
        |> value(:edges, [])
        |> List.wrap()
        |> Enum.map(&preview_edge/1)
    }
  end

  @spec update_node_position(map(), String.t(), integer(), integer()) :: map()
  def update_node_position(spec, node_id, x, y) when is_map(spec) do
    metadata =
      spec
      |> editor_node(node_id)
      |> Map.put("x", x)
      |> Map.put("y", y)

    put_editor_node(spec, node_id, metadata)
  end

  @spec add_action_step(map(), map(), map()) :: map()
  def add_action_step(spec, node, connector)
      when is_map(spec) and is_map(node) and is_map(connector) do
    step = %{
      "name" => node.id,
      "action" => Map.get(connector, "action_key"),
      "opts" => %{},
      "metadata" =>
        compact(%{
          "provider" => Map.get(connector, "provider"),
          "display_name" => Map.get(connector, "display_name"),
          "input_contract" => Map.get(connector, "input_contract"),
          "output_contract" => Map.get(connector, "output_contract"),
          "credential_requirements" => Map.get(connector, "credential_requirements")
        })
    }

    spec
    |> Map.put("steps", List.wrap(Map.get(spec, "steps", [])) ++ [step])
    |> put_editor_node(node.id, %{
      "label" => node.label,
      "type" => "action",
      "x" => node.x,
      "y" => node.y
    })
  end

  @spec update_step_properties(map(), String.t(), map(), map() | nil) :: map()
  def update_step_properties(spec, step_name, attrs, connector \\ nil)
      when is_map(spec) and is_binary(step_name) and is_map(attrs) do
    updated_name = Map.get(attrs, "name", step_name)
    updated_label = Map.get(attrs, "label", humanize(updated_name))
    updated_action = Map.get(attrs, "action")

    spec
    |> rename_step_references(step_name, updated_name)
    |> update_steps(step_name, updated_name, updated_action, connector, attrs)
    |> rename_editor_node(step_name, updated_name, updated_label)
  end

  defp build_nodes(graph, editor_nodes, workflow_nodes) do
    graph
    |> value("nodes", [])
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.reduce({[], MapSet.new()}, fn {node, index}, {acc, seen} ->
      id = node |> value("id") |> to_string()

      cond do
        id == "" ->
          {acc, seen}

        MapSet.member?(seen, id) ->
          {acc, seen}

        true ->
          {acc ++ [preview_node(node, index, editor_nodes, workflow_nodes)], MapSet.put(seen, id)}
      end
    end)
    |> elem(0)
  end

  defp build_edges(graph) do
    graph
    |> value("edges", [])
    |> List.wrap()
    |> Enum.map(&preview_edge/1)
  end

  defp workflow_node(node) do
    data = value(node, :data, %{})
    position = value(node, :position, %{})
    id = node |> value(:id, "step") |> to_string()
    type = node |> value(:type, "step") |> to_string()

    %{
      id: id,
      label: data |> value(:label, id) |> to_string(),
      type: type,
      icon: node_icon(type),
      x: position |> value(:x, @base_x) |> parse_coordinate(),
      y: position |> value(:y, @base_y) |> parse_coordinate()
    }
  end

  defp preview_node(node, index, editor_nodes, workflow_nodes) do
    id = node |> value("id") |> to_string()
    metadata = Map.get(editor_nodes, id, %{})
    workflow_node = Map.get(workflow_nodes, id, %{})
    type = metadata["type"] || Map.get(workflow_node, :type) || infer_type(node)

    %{
      id: id,
      label: metadata["label"] || Map.get(workflow_node, :label) || humanize(id),
      type: type,
      icon: node_icon(type),
      x: metadata["x"] || Map.get(workflow_node, :x) || default_x(index),
      y: metadata["y"] || Map.get(workflow_node, :y) || default_y(index)
    }
  end

  defp preview_edge(edge) do
    source = edge |> value("from", value(edge, "source", "")) |> to_string()
    target = edge |> value("to", value(edge, "target", "")) |> to_string()

    %{
      id: edge |> value("id", "#{source}:#{target}") |> to_string(),
      source: source,
      target: target
    }
  end

  defp previewless_graph(spec) do
    transitions = List.wrap(Map.get(spec, "transitions", []))

    %{
      "nodes" =>
        spec
        |> Map.get("steps", [])
        |> List.wrap()
        |> Enum.map(fn step ->
          %{"id" => Map.get(step, "name"), "action" => Map.get(step, "action")}
        end),
      "edges" =>
        if transitions == [] do
          dependency_edges(spec)
        else
          Enum.map(transitions, fn transition ->
            %{
              "id" =>
                Enum.join(
                  [
                    value(transition, "from", ""),
                    value(transition, "on", ""),
                    value(transition, "to", "")
                  ],
                  ":"
                ),
              "from" => value(transition, "from", ""),
              "to" => value(transition, "to", "")
            }
          end)
        end
    }
  end

  defp dependency_edges(spec) do
    spec
    |> Map.get("steps", [])
    |> List.wrap()
    |> Enum.flat_map(fn step ->
      step
      |> nested_value(["opts", "after"], [])
      |> List.wrap()
      |> Enum.map(fn dependency ->
        %{
          "id" => Enum.join([dependency, "dependency", value(step, "name", "")], ":"),
          "from" => dependency,
          "to" => value(step, "name", "")
        }
      end)
    end)
  end

  defp editor_nodes(spec) do
    spec
    |> nested_value(["editor", "nodes"], %{})
    |> Map.new(fn {key, value} -> {to_string(key), stringify_map(value)} end)
  end

  defp editor_node(spec, node_id) do
    spec
    |> editor_nodes()
    |> Map.get(node_id, %{})
  end

  defp rename_step_references(spec, step_name, step_name), do: spec

  defp rename_step_references(spec, step_name, updated_name) do
    spec
    |> maybe_update("transitions", fn transitions ->
      transitions
      |> List.wrap()
      |> Enum.map(&rename_transition_reference(&1, step_name, updated_name))
    end)
    |> maybe_update("entry_steps", fn entry_steps ->
      entry_steps
      |> List.wrap()
      |> Enum.map(&rename_value(&1, step_name, updated_name))
    end)
    |> maybe_update("initial_step", &rename_value(&1, step_name, updated_name))
    |> maybe_update("entry_step", &rename_value(&1, step_name, updated_name))
  end

  defp rename_transition_reference(transition, step_name, updated_name) when is_map(transition) do
    transition
    |> Map.update("from", nil, &rename_value(&1, step_name, updated_name))
    |> Map.update("to", nil, &rename_value(&1, step_name, updated_name))
  end

  defp rename_transition_reference(transition, _step_name, _updated_name), do: transition

  defp update_steps(spec, step_name, updated_name, updated_action, connector, attrs) do
    Map.update(spec, "steps", [], fn steps ->
      steps
      |> List.wrap()
      |> Enum.map(&update_step(&1, step_name, updated_name, updated_action, connector, attrs))
    end)
  end

  defp update_step(step, step_name, updated_name, updated_action, connector, attrs)
       when is_map(step) do
    if value(step, "name") == step_name do
      step
      |> Map.put("name", updated_name)
      |> maybe_put_action(updated_action)
      |> update_step_metadata(connector)
      |> update_step_metadata_fields(attrs)
      |> update_step_opts(attrs)
      |> update_step_dependencies(step_name, updated_name)
    else
      update_step_dependencies(step, step_name, updated_name)
    end
  end

  defp update_step(step, _step_name, _updated_name, _updated_action, _connector, _attrs), do: step

  defp maybe_put_action(step, nil), do: step
  defp maybe_put_action(step, updated_action), do: Map.put(step, "action", updated_action)

  defp update_step_metadata(step, nil), do: step

  defp update_step_metadata(step, connector) when is_map(connector) do
    metadata =
      step
      |> value("metadata", %{})
      |> stringify_map()
      |> Map.merge(connector_metadata(connector))

    Map.put(step, "metadata", metadata)
  end

  defp connector_metadata(connector) do
    compact(%{
      "provider" => Map.get(connector, "provider"),
      "display_name" => Map.get(connector, "display_name"),
      "input_contract" => Map.get(connector, "input_contract"),
      "output_contract" => Map.get(connector, "output_contract"),
      "credential_requirements" => Map.get(connector, "credential_requirements")
    })
  end

  defp update_step_metadata_fields(step, attrs) do
    notes = normalize_notes(Map.get(attrs, "notes"))
    metadata = step |> value("metadata", %{}) |> stringify_map()
    existing_notes = value(metadata, "notes")

    metadata =
      cond do
        notes in [nil, ""] and is_nil(existing_notes) ->
          metadata

        notes in [nil, ""] ->
          Map.delete(metadata, "notes")

        true ->
          Map.put(metadata, "notes", notes)
      end

    put_or_delete_map(step, "metadata", metadata)
  end

  defp update_step_opts(step, attrs) do
    original_opts = value(step, "opts")
    opts = stringify_map(original_opts)

    opts =
      opts
      |> put_or_delete_opt("input", parse_input_mapping(Map.get(attrs, "input_mapping")))
      |> put_or_delete_opt("output", normalize_output_key(Map.get(attrs, "output_key")))
      |> put_or_delete_opt(
        "retry",
        parse_retry(
          Map.get(attrs, "retry_max_attempts"),
          Map.get(attrs, "retry_backoff_min"),
          Map.get(attrs, "retry_backoff_max")
        )
      )
      |> put_boolean_opt(
        "irreversible",
        Map.get(attrs, "irreversible"),
        value(opts, "irreversible")
      )
      |> put_boolean_opt(
        "compensatable",
        Map.get(attrs, "compensatable"),
        value(opts, "compensatable")
      )

    cond do
      opts != %{} ->
        Map.put(step, "opts", opts)

      is_map(original_opts) ->
        Map.put(step, "opts", %{})

      true ->
        Map.delete(step, "opts")
    end
  end

  defp update_step_dependencies(step, step_name, updated_name) when is_map(step) do
    case value(step, "opts") do
      opts when is_map(opts) ->
        Map.put(
          step,
          "opts",
          opts
          |> stringify_map()
          |> maybe_update("after", fn dependencies ->
            dependencies
            |> List.wrap()
            |> Enum.map(&rename_value(&1, step_name, updated_name))
          end)
        )

      _other ->
        step
    end
  end

  defp rename_editor_node(spec, step_name, updated_name, updated_label) do
    metadata =
      spec
      |> editor_node(step_name)
      |> Map.put("label", updated_label)

    spec
    |> delete_editor_node(step_name, updated_name)
    |> put_editor_node(updated_name, metadata)
  end

  defp delete_editor_node(spec, node_id, node_id), do: spec

  defp delete_editor_node(spec, node_id, _updated_name) do
    editor = Map.get(spec, "editor", %{})
    nodes = editor |> Map.get("nodes", %{}) |> Map.delete(node_id)

    Map.put(spec, "editor", Map.put(editor, "nodes", nodes))
  end

  defp maybe_update(map, key, updater) when is_map(map) and is_function(updater, 1) do
    if Map.has_key?(map, key) do
      Map.update!(map, key, updater)
    else
      map
    end
  end

  defp put_or_delete_map(step, key, map) when is_map(step) and is_binary(key) and is_map(map) do
    if map == %{} do
      Map.delete(step, key)
    else
      Map.put(step, key, map)
    end
  end

  defp put_or_delete_opt(opts, _key, :invalid), do: opts

  defp put_or_delete_opt(opts, key, nil) when is_map(opts) and is_binary(key),
    do: Map.delete(opts, key)

  defp put_or_delete_opt(opts, key, value) when is_map(opts) and is_binary(key),
    do: Map.put(opts, key, value)

  defp put_boolean_opt(opts, key, raw_value, existing_value)
       when is_map(opts) and is_binary(key) do
    if is_nil(raw_value) do
      opts
    else
      apply_boolean_opt(opts, key, parse_boolean(raw_value), existing_value)
    end
  end

  defp parse_input_mapping(value) when value in [nil, ""], do: nil

  defp parse_input_mapping(value) when is_binary(value) do
    case input_mapping_lines(value) do
      [] ->
        nil

      lines ->
        parse_input_mapping_lines(lines)
    end
  end

  defp parse_input_mapping(_value), do: :invalid

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
        :invalid
    end
  end

  defp parse_targeted_input_mapping(lines) do
    Enum.reduce_while(lines, %{}, fn line, acc ->
      [target, path] = String.split(line, "=", parts: 2)

      with {:ok, target} <- parse_mapping_segment(target),
           false <- Map.has_key?(acc, target),
           {:ok, path_segments} <- parse_mapping_path(path) do
        {:cont, Map.put(acc, target, path_segments)}
      else
        :error -> {:halt, :invalid}
        true -> {:halt, :invalid}
      end
    end)
  end

  defp parse_selected_input_mapping(lines) do
    Enum.reduce_while(lines, [], fn line, acc ->
      case parse_mapping_segment(line) do
        {:ok, segment} ->
          continue_selected_input_mapping(acc, segment)

        :error ->
          {:halt, :invalid}
      end
    end)
    |> case do
      :invalid -> :invalid
      segments -> Enum.reverse(segments)
    end
  end

  defp continue_selected_input_mapping(acc, segment) do
    if segment in acc do
      {:halt, :invalid}
    else
      {:cont, [segment | acc]}
    end
  end

  defp parse_mapping_path(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.split(".", trim: true)
    |> parse_mapping_segments()
  end

  defp parse_mapping_path(_value), do: :error

  defp parse_mapping_segments(segments) do
    Enum.reduce_while(segments, [], fn segment, acc ->
      case parse_mapping_segment(segment) do
        {:ok, parsed} -> {:cont, [parsed | acc]}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      [] -> :error
      :error -> :error
      parsed -> {:ok, Enum.reverse(parsed)}
    end
  end

  defp parse_mapping_segment(value) when is_binary(value) do
    value = String.trim(value)

    if value != "" and String.match?(value, @step_key_pattern) do
      {:ok, value}
    else
      :error
    end
  end

  defp parse_mapping_segment(_value), do: :error

  defp normalize_output_key(value) when value in [nil, ""], do: nil

  defp normalize_output_key(value) when is_binary(value) do
    value = String.trim(value)
    if String.match?(value, @step_key_pattern), do: value, else: :invalid
  end

  defp normalize_output_key(_value), do: :invalid

  defp normalize_notes(value) when value in [nil, ""], do: nil
  defp normalize_notes(value) when is_binary(value), do: String.trim(value)
  defp normalize_notes(value), do: to_string(value)

  defp parse_retry(max_attempts, min_delay, max_delay) do
    max_attempts = parse_positive_integer(max_attempts)
    min_delay = parse_optional_positive_integer(min_delay)
    max_delay = parse_optional_positive_integer(max_delay)

    cond do
      max_attempts == nil and is_nil(min_delay) and is_nil(max_delay) ->
        nil

      is_nil(max_attempts) ->
        :invalid

      true ->
        case retry_backoff(min_delay, max_delay) do
          {:ok, nil} ->
            %{"max_attempts" => max_attempts}

          {:ok, backoff} ->
            %{"max_attempts" => max_attempts, "backoff" => backoff}

          :error ->
            :invalid
        end
    end
  end

  defp retry_backoff(nil, nil), do: {:ok, nil}

  defp retry_backoff(min_delay, max_delay)
       when is_integer(min_delay) and is_integer(max_delay) and max_delay >= min_delay do
    {:ok, %{"type" => "exponential", "min" => min_delay, "max" => max_delay}}
  end

  defp retry_backoff(_min_delay, _max_delay), do: :error

  defp apply_boolean_opt(opts, key, {:ok, false}, existing_value) do
    if key == "compensatable" or truthy?(existing_value) or Map.has_key?(opts, key) do
      Map.put(opts, key, false)
    else
      Map.delete(opts, key)
    end
  end

  defp apply_boolean_opt(opts, key, {:ok, true}, _existing_value),
    do: maybe_put_true_boolean_opt(opts, key)

  defp apply_boolean_opt(opts, _key, :error, _existing_value), do: opts

  defp maybe_put_true_boolean_opt(opts, "compensatable") do
    if Map.has_key?(opts, "compensatable") do
      Map.put(opts, "compensatable", true)
    else
      Map.delete(opts, "compensatable")
    end
  end

  defp maybe_put_true_boolean_opt(opts, key), do: Map.put(opts, key, true)

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp parse_positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {integer, ""} when integer > 0 -> integer
      _other -> nil
    end
  end

  defp parse_positive_integer(_value), do: nil

  defp parse_optional_positive_integer(value) when value in [nil, ""], do: nil

  defp parse_optional_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp parse_optional_positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {integer, ""} when integer > 0 -> integer
      _other -> :invalid
    end
  end

  defp parse_optional_positive_integer(_value), do: :invalid

  defp parse_boolean(value) when value in [true, "true", "on", 1, "1"], do: {:ok, true}
  defp parse_boolean(value) when value in [false, "false", nil, "", 0, "0"], do: {:ok, false}
  defp parse_boolean(_value), do: :error

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp put_editor_node(spec, node_id, metadata) do
    editor = Map.get(spec, "editor", %{})
    nodes = editor |> Map.get("nodes", %{}) |> Map.put(node_id, compact(metadata))

    Map.put(spec, "editor", Map.put(editor, "nodes", nodes))
  end

  defp rename_value(value, step_name, updated_name) when value == step_name, do: updated_name
  defp rename_value(value, _step_name, _updated_name), do: value

  defp nested_value(map, [key | rest], default) when is_map(map) do
    map
    |> value(key)
    |> case do
      nil -> default
      value when rest == [] -> value
      value -> nested_value(value, rest, default)
    end
  end

  defp nested_value(_value, _path, default), do: default

  defp stringify_map(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {to_string(key), item} end)
  end

  defp stringify_map(_value), do: %{}

  defp infer_type(node) do
    if value(node, "action") do
      "action"
    else
      "step"
    end
  end

  defp default_x(index), do: @base_x + index * @step_spacing_x
  defp default_y(index), do: @base_y + rem(index, 3) * @step_spacing_y

  defp parse_coordinate(value) when is_integer(value), do: value
  defp parse_coordinate(value) when is_float(value), do: round(value)

  defp parse_coordinate(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> integer
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

  defp humanize(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.replace("-", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp compact(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key) || Map.get(map, to_string(key)) || default

  defp value(_value, _key, default), do: default
end
