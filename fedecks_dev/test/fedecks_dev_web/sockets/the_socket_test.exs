defmodule FedecksDevWeb.TheSocketTest do
  use ExUnit.Case
  alias FedecksDevWeb.TheSocket

  describe "connecting with authorisation" do
    test "when valid returns the identifier" do
      assert {:ok, %{identifier: "nerves-543x"}} =
               TheSocket.connect(%{
                 params: %{
                   "identifier" => "nerves-543x",
                   "username" => "marvin",
                   "password" => "paranoid-android"
                 }
               })
    end

    test "when incorrect, does not connect" do
      assert :error ==
               TheSocket.connect(%{
                 params: %{
                   "identifier" => "nerves-543x",
                   "username" => "marvin@gpp.sirius",
                   "password" => "plastic-pal"
                 }
               })
    end

    test "fails if identifier missing" do
      assert :error ==
               TheSocket.connect(%{
                 params: %{"username" => "marvin", "password" => "paranoid-android"}
               })
    end

    # when extracted - callback
  end

  describe "reconnect with token" do
    test "from refresh enables connection" do
      state = %{identifier: "nerves-987x"}

      assert {:push, {:text, "token:" <> token}, ^state} =
               TheSocket.handle_info(:refresh_token, state)

      assert {:ok, ^state} =
               TheSocket.connect(%{
                 params: %{"connection_token" => token, "identifier" => "nerves-987x"}
               })
    end

    test "does not reconnect if identifier embedded in token does not match that passed as a parameter" do
      {:push, {:text, "token:" <> token}, _} =
        TheSocket.handle_info(:refresh_token, %{identifier: "nerves-111a"})

      assert :error =
               TheSocket.connect(%{
                 params: %{"connection_token" => token, "identifier" => "sciatica-222b"}
               })
    end

    @tag skip: true
    test "does not reconnect if token is invalid" do
      bad_token =
        "QTEyOEdDTQ.CKwjI1Rb4sg6pQsJrFxK-q987C1a-GrSJbROEIjNqS0fX5ydB5lemzhe0k0.SPFzjhDtfPrCpEj3.Oi8hJyFf63T6CioNMmvT-HdU6-pcpwr7gMptnXWj4BM.gL1fYGQRBalNUTC_FPGAEA"

      assert :error ==
               TheSocket.connect(%{
                 params: %{"connection_token" => bad_token, "identifier" => "neves-123x"}
               })
    end
  end

  describe "init" do
    test "passes on the state" do
      assert {:ok, %{identifier: "nerves-123b"}} == TheSocket.init(%{identifier: "nerves-123b"})
    end

    test "initiates sending a new connection token" do
      {:ok, _} = TheSocket.init(%{"identifier" => "nerves-123b"})
      assert_received :refresh_token
    end

    # when extracted callback
  end

  # when extracted deciphers messages
end
