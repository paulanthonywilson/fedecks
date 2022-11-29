defmodule FedecksServer.Socket do
  @moduledoc """
  Sets up a `Phoenix.Socket.Transport` that connects to a Fedecks Websocket client

  Usage:

  tbd

  """
  alias FedecksServer.Token

  @type opcode :: :binary | :text

  @doc """
  Use the fedecks information supplied at login authenticate the user? Only called if there
  is no `fedecks-token` supplied, so is likely to be an initial registration, a re-registration
  (perhaps to associate the device with a new user), or a re-registration due to an expired token which
  can occur if a device has not connected for a few days.

  Will be a map with string keys. The key "fedecks-device-id" will present which you can use
  to associate the device with a user (should you wish).

  """
  @callback authenticate?(map()) :: boolean()

  @doc """
  Can handle incoming text or binary messages.
  - For no reply, return ':ok'
  - To reply, return '{:reply, opcode, message}` where opcode is `:text` or `binary`
  - To terminate the connection, return `{:stop, reason}`
  """
  @callback handle_incoming(opcode(), message :: binary()) ::
              :ok | {:reply, opcode(), message :: binary} | {:stop, term()}

  @doc """
  Called when a new connection is established, with the Fedecks box identifier.
  """
  @callback connection_established(identifier :: String.t()) :: any()

  @doc """
  Called when the connection process has received a message (to its process mailbox). The same as
  `Phoenix.Socket.Transport.handle_info/2` except that internal Fedecks messages, ie `:refresh_token` have been filtered
  out.

  """
  @callback do_handle_info(message :: term(), state :: map()) ::
              {:ok, state :: map()}
              | {:push, {opcode(), message :: binary()}, state :: map()}
              | {:stop, reason :: term, state :: map()}

  @secs_in_4_weeks 60 * 60 * 24 * 7 * 4

  defmacro __using__(opts) do
    otp_app =
      case Keyword.get(opts, :otp_app) do
        nil ->
          raise """
          The application name needs to be passed in to the options, keyed as `:otp_app`, in order to load config
          """

        name ->
          name
      end

    quote do
      @behaviour Phoenix.Socket.Transport
      @behaviour unquote(__MODULE__)

      @impl Phoenix.Socket.Transport
      def child_spec(_) do
        %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
      end

      @impl Phoenix.Socket.Transport
      def connect(%{connect_info: %{x_headers: x_headers}} = h) do
        case List.keyfind(x_headers, "x-fedecks-auth", 0) do
          {_, encoded_auth} -> authenticate_encoded(encoded_auth)
          nil -> :error
        end
      end

      def connect(_), do: :error

      defp authenticate_encoded(encoded_auth) when byte_size(encoded_auth) < 1_024 do
        case Base.decode64(encoded_auth) do
          {:ok, term} -> term |> :erlang.binary_to_term([:safe]) |> authenticate_decoded()
          :error -> :error
        end
      rescue
        ArgumentError ->
          :error
      end

      defp authenticate_encoded(_), do: :error

      defp authenticate_decoded(%{"fedecks-device-id" => device_id, "fedecks-token" => token}) do
        case Token.from_token(token, token_secrets()) do
          {:ok, ^device_id} -> {:ok, %{identifier: device_id}}
          _ -> :error
        end
      end

      defp authenticate_decoded(%{"fedecks-device-id" => device_id} = auth) do
        if authenticate?(auth) do
          {:ok, %{identifier: device_id}}
        else
          :error
        end
      end

      defp authenticate_decoded(_), do: :error

      @impl Phoenix.Socket.Transport
      def init(%{identifier: identifier} = state) do
        send(self(), :refresh_token)
        connection_established(identifier)
        {:ok, state}
      end

      @impl Phoenix.Socket.Transport
      def handle_info(:refresh_token, %{identifier: identifier} = state) do
        Process.send_after(self(), :refresh_token, token_refresh_millis())
        token = Token.to_token(identifier, token_expiry_secs(), token_secrets())
        {:push, {:text, "token:" <> token}, state}
      end

      def handle_info(message, state) do
        do_handle_info(message, state)
      end

      @impl Phoenix.Socket.Transport
      def handle_in({opcode, message}, state) do
        case handle_incoming(opcode, message) do
          :ok -> {:ok, state}
          {:stop, reason} -> {:stop, reason, state}
          {:reply, opcode, message} -> {:reply, :ok, {opcode, message}, state}
        end
      end

      @impl Phoenix.Socket.Transport
      def terminate(_reason, _state) do
        :ok
      end

      @impl unquote(__MODULE__)
      def handle_incoming(_opcode, _message) do
        :ok
      end

      @impl unquote(__MODULE__)
      def do_handle_info(_message, state) do
        {:ok, state}
      end

      @impl unquote(__MODULE__)
      def connection_established(_), do: :ok

      def secret, do: config(:secret)
      def salt, do: config(:salt)
      def token_refresh_millis, do: config(:token_refresh_millis, :timer.hours(3))
      def token_expiry_secs, do: config(:token_expiry_secs, unquote(@secs_in_4_weeks))

      defp token_secrets, do: {secret(), salt()}

      defp config(key, default) do
        unquote(otp_app)
        |> Application.fetch_env!(__MODULE__)
        |> Keyword.get(key, default)
      end

      defp config(key) do
        unquote(otp_app)
        |> Application.fetch_env!(__MODULE__)
        |> Keyword.fetch!(key)
      end

      defoverridable(unquote(__MODULE__))
    end
  end
end
