defmodule FedecksDevWeb.TheSocket do
  @moduledoc """
  Socket side of all of this

  """
  use FedecksServer.Socket, otp_app: :fedecks_dev

  @impl FedecksServer.Socket
  def authenticate?(%{"username" => "marvin", "password" => "paranoid-android"}), do: true
  def authenticate?(_), do: false
end
