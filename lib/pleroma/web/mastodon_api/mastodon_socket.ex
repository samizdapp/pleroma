defmodule Pleroma.Web.MastodonAPI.MastodonSocket do
  use Phoenix.Socket

  alias Pleroma.Web.OAuth.Token
  alias Pleroma.{User, Repo}

  transport :streaming, Phoenix.Transports.WebSocket.Raw,
    timeout: :infinity # We never receive data.

  def connect(params, socket) do
    with token when not is_nil(token) <- params["access_token"],
         %Token{user_id: user_id} <- Repo.get_by(Token, token: token),
         %User{} = user <- Repo.get(User, user_id),
         stream when stream in ["public", "public:local"] <- params["stream"] do
      socket = socket
      |> assign(:topic, params["stream"])
      |> assign(:user, user)
      Pleroma.Web.Streamer.add_socket(params["stream"], socket)
      {:ok, socket}
    else
      _e -> :error
    end
  end

  def id(socket), do: nil

  def handle(:text, message, state) do
    IO.inspect message
    #| :ok
    #| state
    #| {:text, message}
    #| {:text, message, state}
    #| {:close, "Goodbye!"}
    {:text, message}
  end

  def handle(:closed, reason, %{socket: socket}) do
    topic = socket.assigns[:topic]
    Pleroma.Web.Streamer.remove_socket(topic, socket)
  end
end