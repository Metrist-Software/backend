defmodule BackendWeb.BillingLive do
  use BackendWeb, :live_view
  require Logger

  # Plans we bill directly through Stripe
  @stripe_plans Backend.Projections.Membership.stripe_plans()

  @impl true
  def mount(_params, _session, socket) do
    socket = default_assigns(socket)

    {:ok, socket}
  end

  defp default_assigns(socket) do
    socket
    |> assign(
      hide_breadcrumb: true,
      selected_plan: "free",
      stripe_plans: @stripe_plans,
      billing_period: "monthly",
      loading_payment_element: false,
      setup_intent_id: nil,
      submit_loading: false,
      account: %{},
      customer: nil,
      cards: [],
      current_membership: nil
    )
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    account = Backend.Projections.get_account(
      socket.assigns.current_user.account_id,
      [memberships: Backend.Projections.Membership.active_memberships_query()])

    current_membership = List.first(account.memberships)

    existing_tier = case current_membership do
      nil -> :free
      membership -> Map.get(membership, :tier, :free)
    end
    |> Atom.to_string()

    socket = assign(socket,
      account: account,
      selected_plan: existing_tier,
      current_membership: current_membership)

    socket = if connected?(socket) do
      case get_or_create_stripe_customer(account) do
        {:ok, customer} ->
          assign(socket,
            customer: customer,
            account: Map.put(account, :stripe_customer_id, customer.id)
          )
        {:error, err} -> set_stripe_error(socket, err)
      end
    else
      socket
    end

    {:noreply, socket}
  end

  # TODO: Display existing cards
  # defp get_customer_payment_methods(customer) do
  #   case Stripe.PaymentMethod.list(%{customer: customer, type: "card"}) do
  #     {:ok, %{data: payment_methods}} -> payment_methods
  #     _ -> []
  #   end
  # end

  @dialyzer {:nowarn_function, {:get_or_create_stripe_customer, 1}} # Dialyzer is complaining about the Stripe.Customer.create call, but it works fine
  defp get_or_create_stripe_customer(account=%{stripe_customer_id: nil}) do
    Stripe.Customer.create(%{
      name: Backend.Projections.Account.get_account_name(account),
      metadata: %{account_id: account.id}
    })
    |> maybe_dispatch_set_customer_id(account.id)
  end

  defp get_or_create_stripe_customer(%{stripe_customer_id: customer_id}) do
    Stripe.Customer.retrieve(customer_id)
  end

  defp maybe_dispatch_set_customer_id(res={:ok, %{id: customer_id}}, account_id) do
    Backend.App.dispatch(%Domain.Account.Commands.SetStripeCustomerId{
      id: account_id,
      customer_id: customer_id
    })
    res
  end
  defp maybe_dispatch_set_customer_id(res, _account_id), do: res

  @impl true
  def handle_info(:load_payment, socket) do
    socket = if socket.assigns.customer do
      resp = Stripe.SetupIntent.create(%{
        customer: socket.assigns.customer,
        payment_method_types: ["card"]
      })

      case resp do
        {:ok, intent=%Stripe.SetupIntent{}} ->
          socket
          |> push_event("set_payment_client_secret", %{secret: intent.client_secret})
          |> assign(setup_intent_id: intent.id)
        {:error, err} -> set_stripe_error(socket, err)
      end

    else
      put_flash(socket, :error, "Sorry, something went wrong")
    end

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change", vals=%{"plan" => plan}, socket) do
    billing_period = Map.get(vals, "billing_period", socket.assigns.billing_period)

    socket = if plan in @stripe_plans && socket.assigns.selected_plan != plan do
      send(self(), :load_payment)
      assign(socket, loading_payment_element: true)
    else
      socket
    end
    |> assign(
      selected_plan: plan,
      billing_period: billing_period)

    {:noreply, socket}
  end

  def handle_event("submit", %{"plan" => "free"}, socket) do
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(socket, %Domain.Account.Commands.CreateMembership{
      id: socket.assigns.account.id,
      billing_period: "monthly",
      tier: "free"
    })

    socket = assign(socket, current_membership: %Backend.Projections.Membership{
      tier: :free,
      billing_period: :monthly,
    })
    |> put_flash(:info, "Your membership has been successfully updated.")

    {:noreply, socket}
  end

  def handle_event("submit", vals=%{"plan" => plan}, socket) when plan in @stripe_plans do
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(socket, %Domain.Account.Commands.StartMembershipIntent{
      id: socket.assigns.account.id,
      tier: plan,
      billing_period: Map.get(vals, "billing_period", "monthly"),
      callback_reference: socket.assigns.setup_intent_id
    })

    socket = socket
    |> assign(submit_loading: true)
    |> push_event("payment_submit", %{})

    {:noreply, socket}
  end

  def handle_event("submit", %{"plan" => "enterprise"}, socket) do
    Backend.Auth.CommandAuthorization.dispatch_with_auth_check(socket, %Domain.Account.Commands.CreateMembership{
      id: socket.assigns.account.id,
      billing_period: "monthly",
      tier: "enterprise"
    })

    socket = assign(socket, current_membership: %Backend.Projections.Membership{
      tier: :enterprise,
      billing_period: :monthly,
    })
    |> put_flash(:info, "Your request has been submitted. A Metrist team member will contact you soon!")

    {:noreply, socket}
  end

  def handle_event("payment_ready", _, socket) do
    socket = assign(socket, loading_payment_element: false)
    {:noreply, socket}
  end

  def handle_event("payment_error", error, socket) do
    {:noreply, set_stripe_error(socket, error)}
  end

  def handle_event(_event, _message, socket) do
    {:noreply, socket}
  end

  defp set_stripe_error(socket, err) do
    {code, message} = case err do
      %{"code" => code, "message" => message} -> {code, message} # For JS errors
      %{code: code, message: message} -> {code, message}
      _ -> {"unknown", "An unknown error occured`"}
    end

    socket
    |> put_flash(:error, "#{message} (#{code})")
    |> assign(
      submit_loading: false,
      loading_payment_element: false)
  end

  defp membership_is_same_tier?(nil, _plan), do: false
  defp membership_is_same_tier?(%{tier: tier}, plan), do: Atom.to_string(tier) == plan
end
