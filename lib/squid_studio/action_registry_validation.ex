defmodule SquidStudio.ActionRegistryValidation do
  @moduledoc """
  Validates draft step actions against the host-approved catalog.
  """

  @type validation_error :: %{required(String.t()) => [String.t()] | String.t()}

  @spec validate(map(), [map()]) :: [validation_error()]
  def validate(spec, catalog) when is_map(spec) and is_list(catalog) do
    catalog_lookup = Map.new(catalog, &{Map.get(&1, "action_key"), &1})

    spec
    |> Map.get("steps", [])
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.flat_map(fn {step, index} ->
      step
      |> action_error(index, catalog_lookup)
      |> List.wrap()
    end)
  end

  def validate(_spec, _catalog), do: []

  defp action_error(step, index, catalog_lookup) when is_map(step) do
    action_key = value(step, "action")

    cond do
      is_nil(action_key) or action_key == "" ->
        []

      not Map.has_key?(catalog_lookup, action_key) ->
        [error(index, "action", "unknown action #{action_key}")]

      catalog_available?(Map.get(catalog_lookup, action_key)) ->
        []

      true ->
        [error(index, "action", "action #{action_key} is not available for this user")]
    end
  end

  defp action_error(_step, _index, _catalog_lookup), do: []

  defp error(index, field, message) do
    %{
      "path" => ["steps", Integer.to_string(index), field],
      "message" => message
    }
  end

  defp catalog_available?(entry) when is_map(entry) do
    Map.get(entry, "enabled", true) and Map.get(entry, "authorized", true)
  end

  defp catalog_available?(_entry), do: false

  defp value(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))
end
