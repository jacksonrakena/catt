defmodule Catt.Schema do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "cards" do
    field :type, Ecto.Enum, values: [:prompt_d2p3, :prompt_p2, :prompt_normal, :response]
    field :text, :string
    field :author, Ecto.UUID
    field :created_at, :date
  end
end
