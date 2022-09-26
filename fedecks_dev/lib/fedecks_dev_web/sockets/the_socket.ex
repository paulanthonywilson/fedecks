defmodule FedecksDevWeb.TheSocket do
  @moduledoc """
  Socket side of all of this
  """

  alias Fedecks.Token

  @behaviour Phoenix.Socket.Transport

  @secret "oN9+1rGkF1LenvegGZIDTizHTGPssuMl1c69dhbU6wxnYLKTn4raM5WGOSFwFjoA"
  @salt "TK47cxTBuwAA3AQh/PXO8JZmzWlpT9vU45+sRHWpZPWysyeskieZ1Vgp3oFBrPUt"
  @token_secrets {@secret, @salt}

  # 4 weeks
  @token_expiry 60 * 60 * 24 * 7 * 4
  @token_refresh_millis :timer.hours(3)

  def child_spec(_) do
    %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(%{params: %{"connection_token" => token}}) do
    case Token.from_token(token, @token_secrets) do
      {:ok, identifier} ->
        {:ok, %{identifier: identifier}}

      _ ->
        :error
    end
  end

  def connect(%{params: %{"identifier" => identifier} = params}) do
    if authorise?(params) do
      {:ok, %{identifier: identifier}}
    else
      :error
    end
  end

  def connect(_), do: :error

  def init(state) do
    send(self(), :refresh_token)
    {:ok, state}
  end

  def handle_info(:refresh_token, %{identifier: identifier} = state) do
    token = Token.to_token(identifier, @token_expiry, @token_secrets)
    {:push, {:text, "token:" <> token}, state}
  end

  def handle_info(message, state) do
    IO.inspect(message, label: :handle_info)
    {:push, {:text, "handle_info: #{inspect(message)}"}, state}
  end

  def handle_in({_message, _opcode} = message, state) do
    IO.inspect(message, label: :handle_in)
    {:reply, :ok, {:text, "handle_in: #{inspect(message)}"}, state}
  end

  def terminate(reason, _state) do
    IO.inspect(reason, label: :terminate)
    :ok
  end

  def authorise?(%{"username" => "marvin", "password" => "paranoid-android"}), do: true
  def authorise?(_), do: false
end
