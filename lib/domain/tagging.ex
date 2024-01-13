defmodule Domain.Tagging do
  @moduledoc """
  Helpers for tagging. See ADR-0014 for details.
  """

  # Note that this will allow some malformed keys to pass through. For now,
  # we don't care too much.
  @kv_re ~r/^(?<key>[a-zA-Z0-9:.]+):(?<value>[^:]+)$/

  @doc """
  If true, this is a legacy tag. Legacy tags are the tags
  we used initially for grouping monitors on the dashboard:
  aws, gcp, azure, ...
  """
  def is_legacy?(tag)
      when tag in ["aws", "azure", "gcp", "api", "infrastructure", "saas", "other"],
      do: true

  def is_legacy?(_tag), do: false

  @doc """
  If true, this is a valid tag. We don't consider legacy tags to be valid.
  """
  def is_valid?(tag), do: Regex.match?(@kv_re, tag)

  @doc """
  If true, this is a standard tag
  """
  def is_standard?(tag), do: not is_legacy?(tag) and is_valid?(tag)

  @doc """
  Return a tuple with the key and value
  """
  def kv(tag) do
    split = Regex.named_captures(@kv_re, tag)
    {Map.get(split, "key"), Map.get(split, "value")}
  end
end
