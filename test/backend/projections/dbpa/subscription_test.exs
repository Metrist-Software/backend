defmodule Backend.Projection.Dbpa.SubscriptionTest do
  use ExUnit.Case, async: true

  alias Backend.Projections.Dbpa.Subscription

  test "email display is safe" do
    s = %Subscription{delivery_method: "email", display_name: "johnny@example.com"}
    assert "j…y@example.com" == Subscription.safe_display_name(s)
  end

  test "webhook display is safe" do
    s = %Subscription{delivery_method: "webhook", display_name: "https://example.com/path/to/url&stuff?stuff"}
    assert "https://example.com/p…f" == Subscription.safe_display_name(s)

    s = %Subscription{delivery_method: "webhook", display_name: "https://example.com/"}
    assert "https://example.com/" == Subscription.safe_display_name(s)

    s = %Subscription{delivery_method: "webhook", display_name: "https://example.com"}
    assert "https://example.com" == Subscription.safe_display_name(s)
  end

  test "pagerduty display is safe" do
    s = %Subscription{delivery_method: "pagerduty", display_name: "pd_routing_key"}
    assert "p…y" == Subscription.safe_display_name(s)
  end

  test "datadog display is safe" do
    s = %Subscription{delivery_method: "datadog", display_name: "dd_api_key"}
    assert "d…y" == Subscription.safe_display_name(s)
  end

  test "default safe display is just display name" do
    s = %Subscription{delivery_method: "other", display_name: "foo"}
    assert "foo" == Subscription.safe_display_name(s)
  end

  test "short, empty strings aren't ellipsified" do
    assert "" = Subscription.ellipsify(nil)
    assert "" = Subscription.ellipsify("")
    assert "1" = Subscription.ellipsify("1")
    assert "12" = Subscription.ellipsify("12")
    assert "1…3" = Subscription.ellipsify("123")
  end
end
