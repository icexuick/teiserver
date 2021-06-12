defmodule Teiserver.Protocols.Director.SetupTest do
  use Central.ServerCase, async: false
  alias Teiserver.TeiserverTestLib
  alias Teiserver.Battle.BattleLobby
  alias Teiserver.Common.PubsubListener

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0]

  @sleep 50

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "start, stop", %{user: user} do
    battle = TeiserverTestLib.make_battle(%{
      founder_id: user.id,
      founder_name: user.name
    })
    id = battle.id
    assert battle.director_mode == false
    assert ConCache.get(:teiserver_consuls, battle.id) != nil

    # Start it up!
    BattleLobby.say(user.id, "!director start", id)
    :timer.sleep(@sleep)

    battle = BattleLobby.get_battle!(id)
    assert battle.director_mode == true

    # Stop it
    BattleLobby.say(123_456, "!director stop", id)
    :timer.sleep(@sleep)

    battle = BattleLobby.get_battle!(id)
    assert battle.director_mode == false
  end

  test "test command vs no command", %{user: user} do
    battle = TeiserverTestLib.make_battle(%{
      founder_id: user.id,
      founder_name: user.name
    })
    assert battle.director_mode == false

    BattleLobby.start_director_mode(battle.id)
    battle = BattleLobby.get_battle!(battle.id)

    assert battle.director_mode == true
    listener = PubsubListener.new_listener(["battle_updates:#{battle.id}"])

    # No command
    result = BattleLobby.say(123_456, "Test message", battle.id)
    assert result == :ok

    :timer.sleep(@sleep)
    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, battle.id, {123_456, "Test message", battle.id}, :say}]

    # Now command
    result = BattleLobby.say(123_456, "!start", battle.id)
    assert result == :ok

    :timer.sleep(@sleep)
    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, battle.id, {123_456, "!start", battle.id}, :say}]
  end
end