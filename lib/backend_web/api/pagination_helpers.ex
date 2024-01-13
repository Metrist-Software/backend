defmodule BackendWeb.API.PaginationHelpers do
  def metadata_json(%Paginator.Page.Metadata{} = metadata) do
    %{cursor_after: metadata.after, cursor_before: metadata.before}
  end
end
