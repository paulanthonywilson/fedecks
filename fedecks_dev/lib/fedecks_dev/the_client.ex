defmodule FedecksDev.TheClient do
  @moduledoc """
  Connects to the `FedecksDevWeb.TheSocket`
  """
  use WebSockex

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{})
  end
end
