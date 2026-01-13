defmodule ZohoAPI.Validation do
  @moduledoc """
  Input validation helpers for Zoho API requests.

  Provides validation functions to prevent common security issues
  like path injection attacks.
  """

  @doc """
  Validates that an ID is safe to use in URL paths.

  IDs must be alphanumeric with optional underscores and hyphens.
  Path traversal characters (..) and path separators (/, \\) are rejected.

  ## Examples

      iex> Validation.validate_id("12345")
      :ok

      iex> Validation.validate_id("abc_123-xyz")
      :ok

      iex> Validation.validate_id("../admin")
      {:error, "Invalid ID: path traversal not allowed"}

      iex> Validation.validate_id("")
      {:error, "ID cannot be empty"}
  """
  @spec validate_id(String.t()) :: :ok | {:error, String.t()}
  def validate_id(id) when is_binary(id) do
    cond do
      String.trim(id) == "" ->
        {:error, "ID cannot be empty"}

      String.contains?(id, "..") ->
        {:error, "Invalid ID: path traversal not allowed"}

      String.contains?(id, "/") ->
        {:error, "Invalid ID: path separators not allowed"}

      String.contains?(id, "\\") ->
        {:error, "Invalid ID: path separators not allowed"}

      not Regex.match?(~r/^[\w\-]+$/, id) ->
        {:error, "Invalid ID: must contain only alphanumeric characters, underscores, or hyphens"}

      true ->
        :ok
    end
  end

  def validate_id(_), do: {:error, "ID must be a string"}
end
