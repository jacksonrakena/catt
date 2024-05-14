defmodule GameServer do
  alias Phoenix.PubSub
  alias Ecto.UUID
  use GenServer
  require Logger

  # Callbacks

  @impl true
  @spec init(any()) :: {:ok, any()}
  def init(state) do
    Logger.info("Creating game server for #{state.code}")

    {:ok,
     %{
       code: state.code,
       owner_id: state.owner_id,
       players: [state.owner_id],
       state: :lobby,
       current_player: 0
     }}
  end

  def start_link(state) do
    Logger.info(inspect(state))
    GenServer.start(__MODULE__, state)
  end

  @impl true
  def terminate(reason, state) do
    Logger.debug("Terminating game server #{state.code}")
  end

  @impl GenServer
  def handle_call(:get_code, _from, state) do
    {:reply, state, state}
  end

  defp notify_update(state) do
    PubSub.broadcast(Catt.PubSub, state.code, :update)
  end

  def handle_call({:join_game, player_id}, _from, state) do
    notify_update(state)
    Logger.info("#{player_id} joining")
    {:reply, :ok, Map.put(state, :players, [player_id | state.players])}
  end

  def handle_call({:leave_game, player_id}, _from, state) do
    notify_update(state)

    {:reply, :ok,
     Map.put(state, :players, Enum.filter(state.players, fn e -> e != player_id end))}
  end
end
