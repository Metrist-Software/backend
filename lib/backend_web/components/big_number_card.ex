defmodule BackendWeb.Components.BigNumberCard do
  use BackendWeb, :component

  def render(assigns) do
    # Set defaults
    assigns = assigns
    |> assign_new(:number, fn -> 0.0 end)
    |> assign_new(:min, fn -> -1.0e38 end)
    |> assign_new(:max, fn -> 1.0e38 end)
    |> assign_new(:baseline, fn -> nil end)
    |> assign_new(:prefix, fn -> "" end)
    |> assign_new(:baseline_prefix, fn -> "" end)
    |> assign_new(:suffix, fn -> "" end)
    |> assign_new(:baseline_suffix, fn -> "" end)
    |> assign_new(:baseline_name, fn -> "Baseline" end)
    |> assign_new(:hide_baseline, fn -> false end)
    |> assign_new(:data_cy, fn -> "" end)
    |> assign_new(:formatter, fn -> &formatter/1 end)

    # Ensure that we have floats
    assigns = assigns
    |> assign(
      number: as_float(assigns.number),
      baseline: as_float(assigns.baseline),
      min: as_float(assigns.min),
      max: as_float(assigns.max))

    ~H"""
    <div
      class={"flex flex-col py-3 px-4 rounded text-white print:border text-center #{variant(@variant)}"}
      data-cy={@data_cy}
    >
      <div data-cy="bignumbercard-title"><%= @title %></div>
        <div
          class="flex items-baseline mx-auto my-5 font-bold"
          data-cy="bignumbercard-number"
        >
          <span class="mr-2 text-2xl">
            <%= @prefix %>
          </span>
          <span class="text-5xl lg:text-5xl" data-cy="bignumbercard-value">
            <%= @formatter.(clampedNumber(@number, @min, @max)) %>
          </span>
          <span class="ml-2 text-3xl">
            <%= if @number != 0.0, do: @suffix %>
          </span>
        </div>

        <%= cond do %>
          <% @hide_baseline -> %>
            <div>&nbsp;</div>
          <% assigns[:inner_block] -> %>
            <div
              class={"pt-2 mt-2 border-t border-white/50 print:border-white/100 #{print_class(@variant)}"}
              data-cy="bignumbercard-baseline"
            >
              <%= render_slot(@inner_block, %{
                    formatted_baseline: @formatter.(clampedNumber(@baseline, @min, @max)),
                    raw_baseline: @baseline,
                    prefix: @baseline_prefix,
                    suffix: @baseline_suffix}) %>
            </div>
          <% @baseline != nil -> %>
            <div
              class={"pt-2 mt-2 border-t border-white/50 print:border-white/100 #{print_class(@variant)}"}
              data-cy="bignumbercard-baseline"
            >
              <strong>
                <%= @prefix %><%= @formatter.(clampedNumber(@baseline, @min, @max)) %> <%= @suffix %>
              </strong>
              <%= @baseline_name %>
            </div>
          <% true -> %>
            <div>&nbsp;</div>
        <% end %>
      </div>
    """
  end

  def variant(:success), do:
      "bg-green-500 print:border-green-500 print:text-green-500"
  def variant(:warning), do:
      "bg-yellow-500 print:border-yellow-500 print:text-yellow-500"
  def variant(:info), do:
      "bg-blue-500 print:border-blue-500 print:text-blue-500"
  def variant(:danger), do:
      "bg-red-500 print:border-red-500 print:text-red-500"
  def variant(_), do:
      "bg-gray-600 print:border-gray-600 print:text-gray-600"

  def print_class(:success), do: "print:border-green-500"
  def print_class(:warning), do: "print:border-yellow-500"
  def print_class(:info), do: "print:border-blue-300"
  def print_class(:danger), do: "print:border-red-500"
  def print_class(_), do: "print:border-gray-600"

  def clampedNumber(nil, _min, _max), do: nil
  def clampedNumber(n, min, max), do: min(max(n, min), max)

  def as_float(i) when is_integer(i), do: i / 1.0
  def as_float(f), do: f

  def formatter(nil), do: "--"
  def formatter(0.0), do: "--"
  def formatter(f), do: :erlang.float_to_binary(f, decimals: 2)
end
