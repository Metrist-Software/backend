defmodule Domain.UserTest do
  use ExUnit.Case, async: true

  test "Can't process commands without a create" do
    user = %Domain.User{}
    cmd = %Domain.User.Commands.Login{id: "42"}

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:error, :no_create_command_seen} == Domain.User.execute(user, cmd)
    end)
  end

  test "Invite will execute a create as well" do
    user = %Domain.User{}

    cmd = %Domain.User.Commands.CreateInvite{
      id: "user123",
      email: "foo@example.com",
      invite_id: "invite45",
      inviter_id: "user789",
      account_id: "accountABC"
    }

    multi = Domain.User.execute(user, cmd)
    {_user, [created, invite_created]} = Commanded.Aggregate.Multi.run(multi)
    assert created.id == "user123"
    assert "foo@example.com" == Domain.CryptUtils.decrypt_field(created.email)
    assert invite_created == %Domain.User.Events.InviteCreated{
      account_id: "accountABC",
      id: "user123",
      invite_id: "invite45",
      inviter_id: "user789"
    }

    user =
      user
      |> Domain.User.apply(created)
      |> Domain.User.apply(invite_created)

    assert user.id == "user123"
    assert length(user.invites) == 1
  end

  test "Updating an email will result in an encrypted value in event" do
    user = %Domain.User{}

    cmd = %Domain.User.Commands.Create{
      id: "user123",
      user_account_id: nil,
      email: "beforechange@metrist.io",
      uid: "uid",
      is_read_only: false
    }

    created = Domain.User.execute(user, cmd)
    user =
      user
      |> Domain.User.apply(created)

    cmd = %Domain.User.Commands.UpdateEmail{id: user.id, email: "afterchange@metrist.io" }
    updated = Domain.User.execute(user, cmd)

    user =
      user
      |> Domain.User.apply(updated)

    assert updated.email != created.email
    assert String.starts_with?(updated.email, "@enc@:")
    assert String.starts_with?(user.email, "@enc@:")
  end
end
