defmodule Domain.Middleware.TypeValidation do
  @behaviour Commanded.Middleware

  alias Commanded.Middleware.Pipeline

  def before_dispatch(%Pipeline{command: command = %module{}} = pipeline) do
    if Keyword.has_key?(module.__info__(:functions), :ensure_type!) do
      module.ensure_type!(command)
    end
    pipeline
  end

  def after_dispatch(pipeline), do: pipeline
  def after_failure(pipeline), do: pipeline
end
