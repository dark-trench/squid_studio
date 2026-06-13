defmodule SquidStudio.Drafts do
  @moduledoc """
  JSON-safe draft payload helpers for host-owned Squidie workflow persistence.

  Studio never chooses the host storage schema. It normalizes draft payloads at
  the boundary so resolver callbacks can persist plain maps safely.
  """

  @type draft :: map()
  @type normalize_error :: {:invalid_json_value, [String.t()], term()}

  @spec normalize(map()) :: {:ok, draft()} | {:error, normalize_error()}
  def normalize(draft) when is_map(draft) do
    with {:ok, safe} <- json_safe(draft, []) do
      spec = Map.get(safe, "spec", %{})
      id = Map.get(safe, "id") || Map.get(spec, "workflow") || "draft"
      workflow = Map.get(safe, "workflow") || Map.get(spec, "workflow") || id
      name = Map.get(safe, "name") || humanize(workflow)

      definition_version =
        Map.get(safe, "definition_version") || Map.get(spec, "definition_version") || "draft"

      {:ok,
       safe
       |> Map.put("id", to_string(id))
       |> Map.put("workflow", to_string(workflow))
       |> Map.put("name", to_string(name))
       |> Map.put("definition_version", to_string(definition_version))
       |> Map.put("spec", spec)}
    end
  end

  def normalize(value), do: {:error, {:invalid_json_value, [], value}}

  @spec normalize_many(term()) :: {:ok, [draft()]} | {:error, normalize_error()}
  def normalize_many({:ok, drafts}), do: normalize_many(drafts)
  def normalize_many(nil), do: {:ok, []}

  def normalize_many(drafts) when is_list(drafts) do
    Enum.reduce_while(drafts, {:ok, []}, fn draft, {:ok, acc} ->
      case normalize(draft) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      {:error, reason} -> {:error, reason}
    end
  end

  def normalize_many(value), do: {:error, {:invalid_json_value, [], value}}

  @spec from_workflows([map()]) :: [draft()]
  def from_workflows(workflows) when is_list(workflows) do
    workflows
    |> Enum.map(&workflow_to_draft/1)
    |> normalize_many()
    |> case do
      {:ok, drafts} -> drafts
      {:error, _reason} -> []
    end
  end

  def from_workflows(_workflows), do: []

  defp workflow_to_draft(workflow) do
    %{
      id: value(workflow, :id, "draft"),
      workflow: value(workflow, :id, "workflow"),
      name: value(workflow, :name, "Workflow"),
      definition_version: "draft",
      spec: %{
        workflow: value(workflow, :id, "workflow"),
        definition_version: "draft",
        nodes: value(workflow, :nodes, []),
        edges: value(workflow, :edges, [])
      },
      metadata: %{source: "resolver_workflow"}
    }
  end

  defp json_safe(%_struct{} = value, path), do: {:error, {:invalid_json_value, path, value}}

  defp json_safe(map, path) when is_map(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      key = to_string(key)

      case json_safe(value, path ++ [key]) do
        {:ok, safe_value} -> {:cont, {:ok, Map.put(acc, key, safe_value)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp json_safe(list, path) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
      case json_safe(value, path ++ [Integer.to_string(index)]) do
        {:ok, safe_value} -> {:cont, {:ok, [safe_value | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, safe_list} -> {:ok, Enum.reverse(safe_list)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp json_safe(value, _path) when is_binary(value), do: {:ok, value}
  defp json_safe(value, _path) when is_atom(value), do: {:ok, to_string(value)}
  defp json_safe(value, _path) when is_integer(value), do: {:ok, value}
  defp json_safe(value, _path) when is_float(value), do: {:ok, value}
  defp json_safe(value, _path) when is_boolean(value), do: {:ok, value}
  defp json_safe(nil, _path), do: {:ok, nil}
  defp json_safe(value, path), do: {:error, {:invalid_json_value, path, value}}

  defp humanize(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp value(map, key, default), do: Map.get(map, key) || Map.get(map, to_string(key)) || default
end
