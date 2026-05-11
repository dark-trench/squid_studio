defmodule SquidStudio.Web.Helpers do
  @moduledoc false

  alias Phoenix.VerifiedRoutes

  def studio_path(route, params \\ %{})

  def studio_path(route, params) when is_list(route) do
    route
    |> Enum.join("/")
    |> studio_path(params)
  end

  def studio_path(route, params) do
    route = String.trim_leading(route, "/")
    params = params |> Enum.sort() |> encode_params()

    case Process.get(:squid_studio_routing) do
      {socket, prefix} ->
        path = prefixed_path(prefix, route)
        VerifiedRoutes.unverified_path(socket, socket.router, path, params)

      :nowhere ->
        "/"

      nil ->
        raise RuntimeError, "nothing stored in the :squid_studio_routing key"
    end
  end

  def prefixed_path(prefix, route) do
    route = String.trim_leading(route, "/")

    case {prefix, route} do
      {prefix, ""} when prefix in ["", "/"] -> "/"
      {prefix, route} when prefix in ["", "/"] -> "/#{route}"
      {prefix, ""} -> prefix
      {prefix, route} -> "#{prefix}/#{route}"
    end
  end

  defp encode_params([]), do: []

  defp encode_params(params) do
    for {key, value} <- params, value not in [nil, ""] do
      {key, value}
    end
  end
end
