defmodule Catt.GameSupervisor do
  require Logger
  alias Ecto.Query.Builder.Dynamic
  alias Catt.GameSupervisor
  alias Postgrex.Extensions.Numeric
  alias Ecto.UUID
  use DynamicSupervisor
  alias Phoenix.PubSub

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec init(nil) ::
          {:ok,
           %{
             extra_arguments: list(),
             intensity: non_neg_integer(),
             max_children: :infinity | non_neg_integer(),
             period: pos_integer(),
             strategy: :one_for_one
           }}
  def init(nil) do
    {:ok, _} = Registry.start_link(keys: :unique, name: Registry.Catt)
    {:ok, _} = Registry.start_link(keys: :unique, name: Registry.Players)
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec list_games() :: list()
  def list_games() do
    DynamicSupervisor.which_children(Catt.GameSupervisor)
    |> Enum.map(fn {:undefined, pid, _, _} -> GenServer.call(pid, :get_code) end)
  end

  def get_game_by_player(player_id) do
    pid = GenServer.whereis({:via, Registry, {Registry.Players, player_id}})

    if pid != nil do
      GenServer.call(pid, :get_code)
    end
  end

  def get_game_by_code(code) do
    with pid <- get_pid_by_code(code), do: GenServer.call(pid, :get_code)
  end

  def get_pid_by_code(code) do
    GenServer.whereis({:via, Registry, {Registry.Catt, code}})
  end

  def join_game(code, player_id) do
    GameSupervisor.get_pid_by_code(code)
    |> GenServer.call({:join_game, player_id})

    PubSub.broadcast(Catt.PubSub, code, :update)
  end

  def leave_game(code, player_id) do
    pid = GameSupervisor.get_pid_by_code(code)
    GenServer.call(pid, {:leave_game, player_id})

    if !Enum.any?(GameSupervisor.get_game_by_code(code).players) do
      DynamicSupervisor.terminate_child(Catt.GameSupervisor, pid)
      PubSub.broadcast(Catt.PubSub, "global", :update_game_list)
    end

    PubSub.broadcast(Catt.PubSub, code, :update)
  end

  def start_game(owner_id) do
    code =
      UUID.generate()
      |> String.slice(0..5)
      |> String.upcase()
      |> String.split_at(3)
      |> Tuple.to_list()
      |> Enum.join("-")

    child_spec = %{
      id: GameServer,
      start: {GameServer, :start_link, [%{code: code, owner_id: owner_id}]},
      restart: :transient
    }

    {:ok, pid} = DynamicSupervisor.start_child(__MODULE__, child_spec)

    pid |> GenServer.call({:join_game, owner_id})

    PubSub.broadcast(Catt.PubSub, "global", :update_game_list)

    {:ok, code}
  end
end
