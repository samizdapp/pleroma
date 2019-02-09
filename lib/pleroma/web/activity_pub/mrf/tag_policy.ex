# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.TagPolicy do
  alias Pleroma.User
  @behaviour Pleroma.Web.ActivityPub.MRF

  defp get_tags(%User{tags: tags}) when is_list(tags), do: tags
  defp get_tags(_), do: []

  defp process_tag(
         "mrf_tag:media-force-nsfw",
         %{"type" => "Create", "object" => %{"attachment" => child_attachment} = object} = message
       )
       when length(child_attachment) > 0 do
    tags = (object["tag"] || []) ++ ["nsfw"]

    object =
      object
      |> Map.put("tags", tags)
      |> Map.put("sensitive", true)

    message = Map.put(message, "object", object)

    {:ok, message}
  end

  defp process_tag(
         "mrf_tag:media-strip",
         %{"type" => "Create", "object" => %{"attachment" => child_attachment} = object} = message
       )
       when length(child_attachment) > 0 do
    object = Map.delete(object, "attachment")
    message = Map.put(message, "object", object)

    {:ok, message}
  end

  defp process_tag(
         "mrf_tag:force-unlisted",
         %{"type" => "Create", "to" => to, "cc" => cc, "actor" => actor} = message
       ) do
    user = User.get_cached_by_ap_id(actor)

    if Enum.member?(to, "https://www.w3.org/ns/activitystreams#Public") do
      to =
        List.delete(to, "https://www.w3.org/ns/activitystreams#Public") ++ [user.follower_address]

      cc =
        List.delete(cc, user.follower_address) ++ ["https://www.w3.org/ns/activitystreams#Public"]

      object =
        message["object"]
        |> Map.put("to", to)
        |> Map.put("cc", cc)

      message =
        message
        |> Map.put("to", to)
        |> Map.put("cc", cc)
        |> Map.put("object", object)

      {:ok, message}
    else
      {:ok, message}
    end
  end

  defp process_tag(
         "mrf_tag:sandbox",
         %{"type" => "Create", "to" => to, "cc" => cc, "actor" => actor} = message
       ) do
    user = User.get_cached_by_ap_id(actor)

    if Enum.member?(to, "https://www.w3.org/ns/activitystreams#Public") or
         Enum.member?(cc, "https://www.w3.org/ns/activitystreams#Public") do
      to =
        List.delete(to, "https://www.w3.org/ns/activitystreams#Public") ++ [user.follower_address]

      cc = List.delete(cc, "https://www.w3.org/ns/activitystreams#Public")

      object =
        message["object"]
        |> Map.put("to", to)
        |> Map.put("cc", cc)

      message =
        message
        |> Map.put("to", to)
        |> Map.put("cc", cc)
        |> Map.put("object", object)

      {:ok, message}
    else
      {:ok, message}
    end
  end

  defp process_tag(
         "mrf_tag:disable-remote-subscription",
         %{"type" => "Follow", "actor" => actor} = message
       ) do
    user = User.get_cached_by_ap_id(actor)

    if user.local == true do
      {:ok, message}
    else
      {:reject, nil}
    end
  end

  defp process_tag("mrf_tag:disable-any-subscription", %{"type" => "Follow"}), do: {:reject, nil}

  defp process_tag(_, message), do: {:ok, message}

  def filter_message(actor, message) do
    User.get_cached_by_ap_id(actor)
    |> get_tags()
    |> Enum.reduce({:ok, message}, fn
      tag, {:ok, message} ->
        process_tag(tag, message)

      _, error ->
        error
    end)
  end

  @impl true
  def filter(%{"object" => target_actor, "type" => "Follow"} = message),
    do: filter_message(target_actor, message)

  @impl true
  def filter(%{"actor" => actor, "type" => "Create"} = message),
    do: filter_message(actor, message)

  @impl true
  def filter(message), do: {:ok, message}
end