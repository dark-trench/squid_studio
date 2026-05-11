defmodule SquidStudio.Web do
  @moduledoc false

  def html do
    quote do
      @moduledoc false

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      @moduledoc false

      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Phoenix.Component

      import Phoenix.HTML
      import SquidStudio.Web.Helpers

      alias Phoenix.LiveView.JS
      alias SquidStudio.Web.Layouts
    end
  end

  @doc false
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
