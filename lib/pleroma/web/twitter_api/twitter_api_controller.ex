defmodule Pleroma.Web.TwitterAPI.Controller do
  use Pleroma.Web, :controller
  alias Pleroma.Web.TwitterAPI.{TwitterAPI, UserView}
  alias Pleroma.Web.TwitterAPI.Representers.ActivityRepresenter
  alias Pleroma.{Repo, Activity}
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Ecto.Changeset

  def verify_credentials(%{assigns: %{user: user}} = conn, _params) do
    render(conn, UserView, "show.json", %{user: user})
  end

  def status_update(%{assigns: %{user: user}} = conn, %{"status" => status_text} = status_data) do
    l = status_text |> String.trim |> String.length
    if l > 0 && l < 5000 do
      media_ids = extract_media_ids(status_data)
      {:ok, activity} = TwitterAPI.create_status(user, Map.put(status_data, "media_ids",  media_ids))
      conn
      |> json_reply(200, ActivityRepresenter.to_json(activity, %{user: user}))
    else
      empty_status_reply(conn)
    end
  end

  def status_update(conn, _status_data) do
    empty_status_reply(conn)
  end

  defp empty_status_reply(conn) do
    bad_request_reply(conn, "Client must provide a 'status' parameter with a value.")
  end

  defp extract_media_ids(status_data) do
    with media_ids when not is_nil(media_ids) <- status_data["media_ids"],
         split_ids <- String.split(media_ids, ","),
         clean_ids <- Enum.reject(split_ids, fn (id) -> String.length(id) == 0 end)
      do
        clean_ids
      else _e -> []
    end
  end

  def public_and_external_timeline(%{assigns: %{user: user}} = conn, params) do
    statuses = TwitterAPI.fetch_public_and_external_statuses(user, params)
    {:ok, json} = Poison.encode(statuses)

    conn
    |> json_reply(200, json)
  end

  def public_timeline(%{assigns: %{user: user}} = conn, params) do
    statuses = TwitterAPI.fetch_public_statuses(user, params)
    {:ok, json} = Poison.encode(statuses)

    conn
    |> json_reply(200, json)
  end

  def friends_timeline(%{assigns: %{user: user}} = conn, params) do
    statuses = TwitterAPI.fetch_friend_statuses(user, params)
    {:ok, json} = Poison.encode(statuses)

    conn
    |> json_reply(200, json)
  end

  def user_timeline(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.get_user(user, params) do
      {:ok, target_user} ->
        params = Map.merge(params, %{"actor_id" => target_user.ap_id})
        statuses  = TwitterAPI.fetch_user_statuses(user, params)
        conn
        |> json_reply(200, statuses |> Poison.encode!)
      {:error, msg} ->
        bad_request_reply(conn, msg)
    end
  end

  def mentions_timeline(%{assigns: %{user: user}} = conn, params) do
    statuses = TwitterAPI.fetch_mentions(user, params)
    {:ok, json} = Poison.encode(statuses)

    conn
    |> json_reply(200, json)
  end

  def follow(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.follow(user, params) do
      {:ok, user, followed, _activity} ->
        render(conn, UserView, "show.json", %{user: followed, for: user})
      {:error, msg} -> forbidden_json_reply(conn, msg)
    end
  end

  def unfollow(%{assigns: %{user: user}} = conn, params) do
    case TwitterAPI.unfollow(user, params) do
      {:ok, user, unfollowed} ->
        render(conn, UserView, "show.json", %{user: unfollowed, for: user})
      {:error, msg} -> forbidden_json_reply(conn, msg)
    end
  end

  def fetch_status(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    response = Poison.encode!(TwitterAPI.fetch_status(user, id))

    conn
    |> json_reply(200, response)
  end

  def fetch_conversation(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    id = String.to_integer(id)
    response = Poison.encode!(TwitterAPI.fetch_conversation(user, id))

    conn
    |> json_reply(200, response)
  end

  def upload(conn, %{"media" => media}) do
    response = TwitterAPI.upload(media)
    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, response)
  end

  def upload_json(conn, %{"media" => media}) do
    response = TwitterAPI.upload(media, "json")
    conn
    |> json_reply(200, response)
  end

  def get_by_id_or_ap_id(id) do
    Repo.get(Activity, id) || Activity.get_create_activity_by_object_ap_id(id)
  end

  def favorite(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    activity = get_by_id_or_ap_id(id)
    {:ok, status} = TwitterAPI.favorite(user, activity)
    response = Poison.encode!(status)

    conn
    |> json_reply(200, response)
  end

  def unfavorite(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    activity = get_by_id_or_ap_id(id)
    {:ok, status} = TwitterAPI.unfavorite(user, activity)
    response = Poison.encode!(status)

    conn
    |> json_reply(200, response)
  end

  def retweet(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    activity = get_by_id_or_ap_id(id)
    if activity.data["actor"] == user.ap_id do
      bad_request_reply(conn, "You cannot repeat your own notice.")
    else
      {:ok, status} = TwitterAPI.retweet(user, activity)
      response = Poison.encode!(status)

      conn

      |> json_reply(200, response)
    end
  end

  def register(conn, params) do
    with {:ok, user} <- TwitterAPI.register_user(params) do

      render(conn, UserView, "show.json", %{user: user})
    else
      {:error, errors} ->
      conn
      |> json_reply(400, Poison.encode!(errors))
    end
  end

  def update_avatar(%{assigns: %{user: user}} = conn, params) do
    {:ok, object} = ActivityPub.upload(params)
    change = Changeset.change(user, %{avatar: object.data})
    {:ok, user} = Repo.update(change)

    render(conn, UserView, "show.json", %{user: user, for: user})
  end

  def external_profile(%{assigns: %{user: current_user}} = conn, %{"profileurl" => uri}) do
    with {:ok, user_map} <- TwitterAPI.get_external_profile(current_user, uri),
         response <- Poison.encode!(user_map) do
      conn
      |> json_reply(200, response)
    end
  end

  defp bad_request_reply(conn, error_message) do
    json = error_json(conn, error_message)
    json_reply(conn, 400, json)
  end

  defp json_reply(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
  end

  defp forbidden_json_reply(conn, error_message) do
    json = error_json(conn, error_message)
    json_reply(conn, 403, json)
  end

  defp error_json(conn, error_message) do
    %{"error" => error_message, "request" => conn.request_path} |> Poison.encode!
  end
end
