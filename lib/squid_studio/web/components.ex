defmodule SquidStudio.Web.Components do
  @moduledoc false

  use Phoenix.Component

  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(assigns) do
    ~H"""
    <span class={[@name, @class]} aria-hidden="true" />
    """
  end
end
