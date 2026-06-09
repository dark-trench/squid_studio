defmodule SquidStudio.LayoutTestComponent do
  @moduledoc false

  use Phoenix.Component

  alias SquidStudio.Web.Layouts

  attr :flash, :map, required: true

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      Editor
    </Layouts.app>
    """
  end
end
