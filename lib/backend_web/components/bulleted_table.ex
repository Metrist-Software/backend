defmodule BackendWeb.Components.BulletedTable do
  use BackendWeb, :component

  slot :column do
    attr :label, :string, required: true
  end

  attr :rows, :list, default: []
  attr :class, :string, default: ""

  def render(assigns) do
    ~H"""
    <div class={"grid gap-x-1 md:gap-x-5 overflow-x-auto overflow-y-hidden #{@class}"} style={"grid-template-columns: repeat(#{length(@column)}, max-content)"}>
      <%= for col <- @column do %>
        <div class="font-bold">
          <%= col.label %>
        </div>
      <% end %>

      <div id="data_container" class="contents gap-y-5">
        <%!-- TODO: Figure out how to handle phx-update --%>
        <%!-- <div id="data_container" phx-update={@update_action} class="contents"> --%>
        <%= for row <- @rows do %>
          <div class="contents gap-y-5">
            <%= for {col, i} <- Enum.with_index(@column) do %>
              <%= if i == 0 do %>
                <div class="flex flex-row">
                  <div class="flex items-center h-full mt-1">
                    <div class="mr-3 relative h-full">
                      <div class="h-full w-3 flex items-center justify-center">
                        <div class="h-full w-0.5 bg-gray-bright" />
                      </div>
                      <div class="w-3 h-3 absolute top-2 rounded-full bg-gray-bright" />
                    </div>
                  </div>
                  <div class="mt-1">
                    <%= render_slot(col, row) %>
                  </div>
                </div>
              <% else %>
                <div class="mt-1">
                  <%= render_slot(col, row) %>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
