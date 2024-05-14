defmodule CattWeb.GameLive do
  alias Catt.GameSupervisor
  alias Ecto.UUID
  alias CattWeb.CoreComponents
  alias Phoenix.Flash
  use CattWeb, :live_view
  require Ecto.Query
  require Logger
  alias Catt.Accounts

  def render(assigns) do
    ~H"""
    <%= if @code == nil do %>
      <button phx-click="start_game">Start new game</button>
      <h3>All games</h3>
      <ul>
        <%= for pid <- @games do %>
          <li>
            <button phx-click="join_game" phx-value-id={pid.code}>
              <%= pid.code %> (owned by <%= pid.owner_id %>)
            </button>
          </li>
        <% end %>
      </ul>
    <% else %>
      Your game code: <%= @code %>
      <br /> State: <%= @state.state %>
      <br /> Players:
      <ul>
        <%= for player <- @state.players do %>
          <li><%= Accounts.get_user!(player).email %></li>
        <% end %>
      </ul>
      <%= inspect(@state) %>
      <button phx-click="leave_game">Leave game</button>
    <% end %>
    """
  end

  def on_mount(:default, _params, %{"user_token" => user_token} = _session, socket) do
    socket =
      assign_new(socket, :current_user, fn ->
        Accounts.get_user_by_session_token(user_token)
      end)

    if socket.assigns.current_user.confirmed_at do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/login")}
    end
  end

  @spec mount(any(), any(), atom() | %{:id => any(), optional(any()) => any()}) :: {:ok, any()}
  def mount(_params, session, socket) do
    Phoenix.PubSub.subscribe(Catt.PubSub, "global")

    case GameSupervisor.get_game_by_player(socket.assigns.current_user.id) do
      lobby when not is_nil(lobby) ->
        Phoenix.PubSub.subscribe(Catt.PubSub, lobby.code)

        {:ok,
         assign(socket, %{
           code: lobby.code,
           games: [],
           state: lobby,
           user_id: socket.assigns.current_user.email
         })}

      nil ->
        {:ok,
         assign(socket, %{
           prompt_card: nil,
           response_cards: [],
           code: nil,
           user_id: socket.assigns.current_user.email,
           games: GameSupervisor.list_games()
         })}
    end
  end

  def handle_event("join_game", params, socket) do
    Logger.info(inspect(params))

    id = Map.get(params, "id")
    GameSupervisor.join_game(id, socket.assigns.current_user.id)

    {:noreply,
     assign(socket, %{
       code: id,
       games: [],
       state: GameSupervisor.get_game_by_code(id)
     })}
  end

  def handle_event("leave_game", _params, socket) do
    GameSupervisor.leave_game(socket.assigns.code, socket.assigns.current_user.id)

    {:noreply, assign(socket, %{code: nil, games: [], state: nil})}
  end

  def handle_event("start_game", _params, socket) do
    {:ok, code} = GameSupervisor.start_game(socket.assigns.current_user.id)

    handle_join(code)

    {:noreply,
     assign(socket, %{
       code: code,
       games: [],
       state: GameSupervisor.get_game_by_code(code)
     })}
  end

  @impl true
  def handle_info(:update, socket) do
    state = GameSupervisor.get_game_by_code(socket.assigns.code)

    if state == nil do
      {:noreply,
       assign(socket, %{
         code: nil,
         games: GameSupervisor.list_games(),
         state: nil
       })}
    end

    {:noreply,
     assign(socket, %{
       code: socket.assigns.code,
       games: [],
       state: state
     })}
  end

  def handle_info(:update_game_list, socket) do
    {
      :noreply,
      assign(socket, %{
        games: GameSupervisor.list_games()
      })
    }
  end

  @spec handle_join(binary()) :: :ok | {:error, {:already_registered, pid()}}
  def handle_join(code) do
    Phoenix.PubSub.subscribe(Catt.PubSub, code)
  end
end
