defmodule BackendWeb.SubscriptionController do
  use BackendWeb, :controller

  def delete(conn, %{"token" => token}) do
    conn = case BackendWeb.Token.verify_and_validate(token) do
      {:ok, claims} -> do_unsubscribe(conn, claims)
      _ -> put_flash(conn, :error, "Invalid unsubscribe token")
    end

    render(conn, "unsubscribe.html", spoofing?: false)
  end

  def delete(conn, _) do
    conn
    |> put_flash(:error, "Missing unsubscribe token")
    |> render("unsubscribe.html", spoofing?: false)
  end

  defp do_unsubscribe(conn, %{"accountId" => account_id, "subscriptionId" => subscription_id, "action" => "unsubscribe"}) do
    cmd = %Domain.Account.Commands.DeleteSubscriptions{
      id: account_id,
      subscription_ids: [subscription_id]
    }

    case Backend.App.dispatch(cmd) do
      :ok -> put_flash(conn, :info, "Subscription successfully removed!")
      {:error, _} -> put_flash(conn, :error, "Error removing subscription")
    end
  end
  defp do_unsubscribe(conn, _), do: put_flash(conn, :error, "Invalid unsubscribe token")
end
