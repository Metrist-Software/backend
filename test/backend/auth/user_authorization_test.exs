defmodule Backend.Auth.CommandAuthorizationTest do
  use ExUnit.Case, async: true

  alias Backend.Auth.CommandAuthorization
  require Logger

  test "read-only user cannot choose monitors" do
    command = %Domain.Account.Commands.ChooseMonitors{
      add_monitors: [],
      id: "fake_id",
      remove_monitors: ["test"],
      user_id: "fake_id"
    }
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        current_user: %Backend.Projections.User{
          id: "fake_user_id",
          account_id: "fake_id",
          is_read_only: true,
        }
      }
    }
    assert CommandAuthorization.dispatch_with_auth_check(socket, command) == {:error, :read_only_user}
  end

  test "admin user can add subscriptions" do
    command = %Domain.Account.Commands.AddSubscriptions{
      id: "fake id",
      subscriptions: []
    }
    user = %Backend.Projections.User{is_metrist_admin: true}
    assert CommandAuthorization.can?(user, :command, command) == true
  end

  test "read-only user cannot add subscriptions" do
    command = %Domain.Account.Commands.AddSubscriptions{
      id: "fake id",
      subscriptions: []
    }
    user = %Backend.Projections.User{is_read_only: true}
    assert CommandAuthorization.can?(user, :command, command) == false
  end

  test "non read-only user can remove subscriptions" do
    command = %Domain.Account.Commands.DeleteSubscriptions{
      id: "fake id",
      subscription_ids: []
    }
    user = %Backend.Projections.User{is_read_only: false}
    assert CommandAuthorization.can?(user, :command, command) == true
  end

  test "read-only user can update timezone" do
    command = %Domain.User.Commands.UpdateTimezone{
      id: "fake id",
      timezone: "fake timezone"
    }
    user = %Backend.Projections.User{is_read_only: true}
    assert CommandAuthorization.can?(user, :command, command) == true
  end

  test "read-only user can print" do
    command = %Domain.User.Commands.Print{
      id: "fake id",
    }
    user = %Backend.Projections.User{is_read_only: true}
    assert CommandAuthorization.can?(user, :command, command) == true
  end

  test "read-only user can logout" do
    command = %Domain.User.Commands.Logout{
      id: "fake id",
    }
    user = %Backend.Projections.User{is_read_only: true}
    assert CommandAuthorization.can?(user, :command, command) == true
  end

  test "read-only user can login" do
    command = %Domain.User.Commands.Login{
      id: "fake id",
    }
    user = %Backend.Projections.User{is_read_only: true}
    assert CommandAuthorization.can?(user, :command, command) == true
  end

end
