defmodule Tune.Spotify.Schema.User do
  @moduledoc """
  Represents a Spotify user.
  """

  @enforce_keys [:name, :avatar_url, :product, :id]
  defstruct [:name, :avatar_url, :product, :id]

  @type t :: %__MODULE__{
          name: String.t(),
          avatar_url: String.t(),
          product: String.t(),
          id: String.t()
        }

  @spec premium?(t()) :: boolean()
  def premium?(%__MODULE__{product: product}), do: product == "premium"
end
