defmodule CattWeb.GameLive do
  use CattWeb, :live_view
  require Ecto.Query

  def render(assigns) do
    ~H"""
    <%= @temperature.text %> <button phx-click="inc_temperature"></button>
    <br />
    <br />
    <ul>
      <%= for response_card <- @response_cards do %>
        <li><%= response_card.text %></li>
      <% end %>
    </ul>
    """
  end

  def mount(_params, _session, socket) do
    prompt_card =
      Catt.Schema
      |> Ecto.Query.where(type: :prompt_normal)
      |> Ecto.Query.order_by(fragment("RANDOM()"))
      |> Ecto.Query.limit(1)
      |> Catt.Repo.one()

    response_cards =
      Catt.Schema
      |> Ecto.Query.where(type: :response)
      |> Ecto.Query.order_by(fragment("RANDOM()"))
      |> Ecto.Query.limit(5)
      |> Catt.Repo.all()

    {:ok, assign(socket, %{temperature: prompt_card, response_cards: response_cards})}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end
end
