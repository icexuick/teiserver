defmodule Teiserver.Bridge.DiscordBridge do
  # use Alchemy.Cogs
  use Alchemy.Events
  alias Teiserver.{Account, Room}
  alias Central.Account.ReportLib
  alias Teiserver.Bridge.BridgeServer
  require Logger

  @emoticon_map %{
    "🙂" => ":)",
    "😒" => ":s",
    "😦" => ":(",
    "😛" => ":p",
    "😄" => ":D",
  }

  @extra_text_emoticons %{
    ":S" => "😒",
    ":P" => "😛",
  }

  @text_to_emoticon_map @emoticon_map
  |> Map.new(fn {k, v} -> {v, k} end)
  |> Map.merge(@extra_text_emoticons)

  @spec get_text_to_emoticon_map() :: Map.t()
  def get_text_to_emoticon_map, do: @text_to_emoticon_map

  Events.on_message(:inspect)
  @spec inspect(atom | %{:attachments => any, optional(any) => any}) :: nil | :ok
  def inspect(%Alchemy.Message{author: author, channel_id: channel_id, attachments: []} = message) do
    room = bridge_channel_to_room(channel_id)

    cond do
      author.username == Application.get_env(:central, DiscordBridge)[:bot_name] ->
        nil

      room == nil ->
        nil

      room == "moderators" ->
        nil

      true ->
        do_reply(message)
    end
  end

  def inspect(message) do
    cond do
      message.attachments != [] ->
        :ok

      # We expected to be able to handle it but didn't, what's happening?
      true ->
        Logger.debug("Unhandled DiscordBridge event: #{Kernel.inspect message}")
    end
  end

  def moderator_action(report_id) do
    result = Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_chan, room} -> room == "moderators" end)

    chan = case result do
      [{chan, _}] -> chan
      _ -> nil
    end

    if chan do
      report = Account.get_report!(report_id, preload: [:responder, :target])
      past_tense = ReportLib.past_tense(report.response_action)

      if past_tense != nil do
        msg = "#{report.target.name} was #{past_tense} by #{report.responder.name} for reason #{report.reason}"

        Alchemy.Client.send_message(
          chan,
          "Moderator action: #{msg}",
          []# Options
        )
      end
    end
  end

  defp do_reply(%Alchemy.Message{author: author, content: content, channel_id: channel_id, mentions: mentions}) do
    # Mentions come through encoded in a way we don't want to preserve, this substitutes them
    new_content = mentions
    |> Enum.reduce(content, fn (m, acc) ->
      String.replace(acc, "<@!#{m.id}>", m.username)
    end)
    |> String.replace(~r/<#[0-9]+> ?/, "")
    |> convert_emoticons
    |> String.split("\n")
    |> Enum.map(fn row ->
      "#{author.username}: #{row}"
    end)

    from_id = BridgeServer.get_bridge_userid()
    room = bridge_channel_to_room(channel_id)
    Room.send_message(from_id, room, new_content)
  end

  defp convert_emoticons(msg) do
    msg
    |> String.replace(Map.keys(@emoticon_map), fn emoji -> @emoticon_map[emoji] end)
  end

  defp bridge_channel_to_room(channel_id) do
    result = Application.get_env(:central, DiscordBridge)[:bridges]
    |> Enum.filter(fn {chan, _room} -> chan == channel_id end)

    case result do
      [{_, room}] -> room
      _ -> nil
    end
  end
end
