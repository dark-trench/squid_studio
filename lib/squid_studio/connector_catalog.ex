defmodule SquidStudio.ConnectorCatalog do
  @moduledoc """
  JSON-safe metadata for host-approved connector actions.

  Hosts own the real integration credentials and authorization decisions.
  Studio only keeps display metadata, contracts, and credential requirements.
  """

  @type entry :: map()
  @type normalize_error :: {:invalid_json_value, [String.t()], term()}

  @credential_keys ~w(key label description required reference scopes)

  @spec normalize(map()) :: {:ok, entry()} | {:error, normalize_error()}
  def normalize(entry) when is_map(entry) do
    with {:ok, safe} <- json_safe(entry, []),
         {:ok, credential_requirements} <-
           normalize_credential_requirements(Map.get(safe, "credential_requirements", [])) do
      provider = required_string(safe, "provider", "built_in")
      category = required_string(safe, "category", "General")
      action_key = required_string(safe, "action_key", provider)
      display_name = required_string(safe, "display_name", humanize(action_key))

      {:ok,
       %{
         "provider" => provider,
         "category" => category,
         "action_key" => action_key,
         "display_name" => display_name,
         "description" => required_string(safe, "description", ""),
         "input_contract" => Map.get(safe, "input_contract", %{}),
         "output_contract" => Map.get(safe, "output_contract", %{}),
         "credential_requirements" => credential_requirements,
         "enabled" => Map.get(safe, "enabled", true),
         "authorized" => Map.get(safe, "authorized", true),
         "disabled_reason" => Map.get(safe, "disabled_reason")
       }}
    end
  end

  def normalize(value), do: {:error, {:invalid_json_value, [], value}}

  @spec normalize_many(term()) :: {:ok, [entry()]} | {:error, normalize_error()}
  def normalize_many({:ok, entries}), do: normalize_many(entries)
  def normalize_many({:error, reason}), do: {:error, reason}
  def normalize_many(nil), do: {:ok, []}

  def normalize_many(entries) when is_list(entries) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case normalize(entry) do
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

  @spec group_by_category([entry()]) :: [%{category: String.t(), entries: [entry()]}]
  def group_by_category(entries) when is_list(entries) do
    entries
    |> Enum.group_by(&Map.get(&1, "category", "General"))
    |> Enum.sort_by(fn {category, _entries} -> String.downcase(to_string(category)) end)
    |> Enum.map(fn {category, entries} ->
      %{
        category: category,
        entries: Enum.sort_by(entries, &String.downcase(Map.get(&1, "display_name", "")))
      }
    end)
  end

  def group_by_category(_entries), do: []

  defp normalize_credential_requirements(credentials) when is_list(credentials) do
    {:ok, Enum.map(credentials, &normalize_credential_requirement/1)}
  end

  defp normalize_credential_requirements(credentials) when is_map(credentials) do
    {:ok, [normalize_credential_requirement(credentials)]}
  end

  defp normalize_credential_requirements(_credentials), do: {:ok, []}

  defp normalize_credential_requirement(credential) when is_map(credential) do
    credential
    |> Map.take(@credential_keys)
    |> Map.put_new("key", required_string(credential, "key", "credential"))
    |> Map.put_new(
      "label",
      required_string(credential, "label", humanize(Map.get(credential, "key")))
    )
    |> Map.put_new("required", true)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_credential_requirement(credential) do
    key = to_string(credential)

    %{
      "key" => key,
      "label" => humanize(key),
      "required" => true
    }
  end

  defp json_safe(%_struct{} = value, path), do: {:error, {:invalid_json_value, path, value}}

  defp json_safe(map, path) when is_map(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, key} <- safe_key(key, path),
           {:ok, safe_value} <- json_safe(value, path ++ [key]) do
        {:cont, {:ok, Map.put(acc, key, safe_value)}}
      else
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
  defp json_safe(value, _path) when is_boolean(value), do: {:ok, value}
  defp json_safe(value, _path) when is_atom(value), do: {:ok, to_string(value)}
  defp json_safe(value, _path) when is_integer(value), do: {:ok, value}
  defp json_safe(value, _path) when is_float(value), do: {:ok, value}
  defp json_safe(nil, _path), do: {:ok, nil}
  defp json_safe(value, path), do: {:error, {:invalid_json_value, path, value}}

  defp safe_key(key, path) do
    {:ok, to_string(key)}
  rescue
    Protocol.UndefinedError -> {:error, {:invalid_json_value, path, key}}
  end

  defp required_string(map, key, default) do
    case Map.get(map, key) do
      value when value in [nil, ""] -> to_string(default)
      value -> to_string(value)
    end
  end

  defp humanize(nil), do: "Credential"

  defp humanize(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
