defmodule Teiserver.Coordinator.ConsulCommands do
  require Logger
  alias Teiserver.Coordinator.ConsulServer
  alias Teiserver.{Coordinator, User, Client}
  alias Teiserver.Battle.{Lobby, LobbyChat}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  # alias Phoenix.PubSub
  # alias Teiserver.Data.Types, as: T

  @doc """
    Command has structure:
    %{
      raw: string,
      remaining: string,
      command: nil | string,
      senderid: userid
    }
  """
  @spec handle_command(Map.t(), Map.t()) :: Map.t()

  #################### For everybody
  def handle_command(%{command: "status", senderid: senderid} = _cmd, state) do
    status_msg = [
      "Status for battle ##{state.lobby_id}",
      "Gatekeeper: #{state.gatekeeper}"
    ]
    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "help", senderid: senderid} = _cmd, state) do
    status_msg = [
      "Command list can currently be found at https://github.com/beyond-all-reason/teiserver/blob/master/lib/teiserver/coordinator/coordinator_lib.ex"
    ]
    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  # TODO: splitlobby command

  #################### Moderator only
  # ----------------- General commands
  def handle_command(%{command: "gatekeeper", remaining: mode} = cmd, state) do
    state = case mode do
      "blacklist" ->
        %{state | gatekeeper: :blacklist}
      "whitelist" ->
        %{state | gatekeeper: :whitelist}
      "friends" ->
        %{state | gatekeeper: :friends}
      "friendsjoin" ->
        %{state | gatekeeper: :friendsjoin}
      "clan" ->
        %{state | gatekeeper: :clan}
      _ ->
        state
    end
    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "welcome-message", remaining: remaining} = cmd, state) do
    new_state = case String.trim(remaining) do
      "" ->
        %{state | welcome_message: nil}
      msg ->
        Lobby.say(cmd.senderid, "New welcome message set to: #{msg}", state.lobby_id)
        %{state | welcome_message: msg}
    end
    ConsulServer.broadcast_update(new_state)
  end

  def handle_command(%{command: "specunready"} = cmd, state) do
    battle = Lobby.get_lobby!(state.lobby_id)

    battle.players
    |> Enum.each(fn player_id ->
      client = Client.get_client_by_id(player_id)
      if client.ready == false do
        User.ring(player_id, state.coordinator_id)
        Lobby.force_change_client(state.coordinator_id, player_id, %{player: false})
      end
    end)

    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "makeready", remaining: ""} = cmd, state) do
    battle = Lobby.get_lobby!(state.lobby_id)

    battle.players
    |> Enum.each(fn player_id ->
        User.ring(player_id, state.coordinator_id)
      Lobby.force_change_client(state.coordinator_id, player_id, %{ready: true})
    end)

    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "makeready", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      player_id ->
        User.ring(player_id, state.coordinator_id)
        Lobby.force_change_client(state.coordinator_id, player_id, %{ready: true})
        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "pull", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.force_add_user_to_battle(target_id, state.lobby_id)
        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "settag", remaining: remaining} = cmd, state) do
    case String.split(remaining, " ") do
      [key, value | _] ->
        battle = Lobby.get_lobby!(state.lobby_id)
        new_tags = Map.put(battle.tags, String.downcase(key), value)
        Lobby.set_script_tags(state.lobby_id, new_tags)
        ConsulServer.say_command(cmd, state)
      _ ->
        ConsulServer.say_command(%{cmd | error: "no regex match"}, state)
    end
  end

  # ----------------- Moderation commands
  # TODO: modwarn

  def handle_command(cmd = %{command: "modmute", remaining: remaining}, state) do
    [username, minutes | reason] = String.split(remaining, " ")
    reason = Enum.join(reason, " ")

    userid = ConsulServer.get_user(username, state)
    until = "#{minutes} minutes"

    case Central.Account.ReportLib.perform_action(%{}, "Mute", until) do
      {:ok, expires} ->
        {:ok, _report} =
          Central.Account.create_report(%{
            "location" => "battle-lobby",
            "location_id" => nil,
            "reason" => reason,
            "reporter_id" => cmd.senderid,
            "target_id" => userid,
            "response_text" => "instant-action",
            "response_action" => "Mute",
            "expires" => expires,
            "responder_id" => cmd.senderid
          })

        user = User.get_user_by_id(userid)
        sender = User.get_user_by_id(cmd.senderid)
        LobbyChat.say(state.coordinator_id, "#{user.name} muted for #{minutes} minutes by #{sender.name}, reason: #{reason}", state.lobby_id)
      _ ->
        LobbyChat.sayprivateex(state.coordinator_id, cmd.senderid, "Unable to find a user by that name", state.lobby_id)
    end

    state
  end

  def handle_command(cmd = %{command: "modban", remaining: remaining}, state) do
    [username, minutes | reason] = String.split(remaining, " ")
    reason = Enum.join(reason, " ")

    userid = ConsulServer.get_user(username, state)
    until = "#{minutes} minutes"

    case Central.Account.ReportLib.perform_action(%{}, "Ban", until) do
      {:ok, expires} ->
        {:ok, _report} =
          Central.Account.create_report(%{
            "location" => "battle-lobby",
            "location_id" => nil,
            "reason" => reason,
            "reporter_id" => cmd.senderid,
            "target_id" => userid,
            "response_text" => "instant-action",
            "response_action" => "Ban",
            "expires" => expires,
            "responder_id" => cmd.senderid
        })

        user = User.get_user_by_id(userid)
        sender = User.get_user_by_id(cmd.senderid)
        LobbyChat.say(state.coordinator_id, "#{user.name} banned for #{minutes} minutes by #{sender.name}, reason: #{reason}", state.lobby_id)
      _ ->
        LobbyChat.sayprivateex(state.coordinator_id, cmd.senderid, "Unable to find a user by that name", state.lobby_id)
    end

    state
  end

  def handle_command(%{command: "speclock", remaining: target} = _cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        state
      target_id ->
        new_blacklist = Map.put(state.blacklist, target_id, :spectator)
        new_whitelist = Map.put(state.whitelist, target_id, :spectator)
        Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})

        %{state | blacklist: new_blacklist, whitelist: new_whitelist}
        |> ConsulServer.broadcast_update("lock-spectator")
    end
  end

  def handle_command(%{command: "forceplay", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        state
      target_id ->
        Lobby.force_change_client(state.coordinator_id, target_id, %{player: true})
        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "lobbyban", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        ban = new_ban(%{level: :banned}, state)
        new_bans = Map.put(state.bans, target_id, ban)

        Lobby.kick_user_from_battle(target_id, state.lobby_id)

        ConsulServer.say_command(cmd, state)

        %{state | bans: new_bans}
        |> ConsulServer.broadcast_update("ban")
    end
  end

  def handle_command(%{command: "lobbybanmult", remaining: targets} = cmd, state) do
    ConsulServer.say_command(cmd, state)

    String.split(targets, " ")
    |> Enum.reduce(state, fn (target, acc) ->
      case ConsulServer.get_user(target, acc) do
        nil ->
          acc
        target_id ->
          new_blacklist = Map.put(acc.blacklist, target_id, :banned)
          new_whitelist = Map.delete(acc.blacklist, target_id)
          Lobby.kick_user_from_battle(target_id, acc.lobby_id)

          %{acc | blacklist: new_blacklist, whitelist: new_whitelist}
          |> ConsulServer.broadcast_update("ban")
      end
    end)
  end

  def handle_command(%{command: "unban", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        new_blacklist = Map.delete(state.blacklist, target_id)
        ConsulServer.say_command(cmd, state)

        %{state | blacklist: new_blacklist}
        |> ConsulServer.broadcast_update("unban")
    end
  end


  def handle_command(%{command: "reset"} = _cmd, state) do
    ConsulServer.empty_state(state.lobby_id)
    |> ConsulServer.broadcast_update("reset")
  end

  #################### Internal commands
  # Would need to be sent by internal since battlestatus isn't part of the command queue
  def handle_command(%{command: "change-battlestatus", remaining: target_id, status: new_status}, state) do
    Lobby.force_change_client(state.coordinator_id, target_id, new_status)
    state
  end

  def handle_command(cmd, state) do
    if Map.has_key?(cmd, :raw) do
      LobbyChat.do_say(cmd.senderid, cmd.raw, state.lobby_id)
    else
      Logger.error("No handler in consul_server for command #{Kernel.inspect cmd}")
    end
    state
  end

  defp new_ban(data, state) do
    Map.merge(%{
      by: state.coordinator_id,
      reason: "None given",
      # :player | :spectator | :banned
      level: :banned
    }, data)
  end
end
