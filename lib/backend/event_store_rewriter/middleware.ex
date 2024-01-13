defmodule Backend.EventStoreRewriter.Middleware do
  @behaviour Commanded.Middleware

  alias Commanded.Middleware.Pipeline

  def before_dispatch(pipeline) do
    case Backend.EventStoreRewriter.RewriteTask.get_status() do
      :finalizing -> Pipeline.halt(pipeline)
      _ -> pipeline
    end
  end

  def after_dispatch(pipeline), do: pipeline
  def after_failure(pipeline), do: pipeline
end
