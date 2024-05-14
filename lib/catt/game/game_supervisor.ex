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
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec list_games() :: list()
  def list_games() do
    DynamicSupervisor.which_children(Catt.GameSupervisor)
    |> Enum.map(fn {:undefined, pid, type, module} -> pid end)
    |> Enum.map(fn pid -> GenServer.call(pid, :get_code) end)
  end

  def try_find_existing_lobby(player_id) do
    DynamicSupervisor.which_children(Catt.GameSupervisor)
    |> Enum.map(fn {:undefined, pid, type, module} -> GenServer.call(pid, :get_code) end)
    |> Enum.filter(fn state -> Enum.member?(state.players, player_id) end)
    |> List.first()
  end

  def get_game_by_code(code) do
    DynamicSupervisor.which_children(Catt.GameSupervisor)
    |> Enum.map(fn {:undefined, pid, type, module} -> GenServer.call(pid, :get_code) end)
    |> Enum.filter(fn state -> state.code == code end)
    |> List.first()
  end

  def get_pid_by_code(code) do
    DynamicSupervisor.which_children(Catt.GameSupervisor)
    |> Enum.map(fn {:undefined, pid, type, module} ->
      {pid, GenServer.call(pid, :get_code)}
    end)
    |> Enum.filter(fn {pid, data} -> data.code == code end)
    |> Enum.map(fn {pid, data} -> pid end)
    |> List.first()
  end

  def join_game(code, player_id) do
    game = GameSupervisor.get_game_by_code(code)
    pid = get_pid_by_code(code)
    GenServer.call(pid, {:join_game, player_id})

    PubSub.broadcast(Catt.PubSub, code, :update)
  end

  def leave_game(code, player_id) do
    game = GameSupervisor.get_game_by_code(code)
    pid = get_pid_by_code(code)
    GenServer.call(pid, {:leave_game, player_id})

    if !Enum.any?(GameSupervisor.get_game_by_code(code).players) do
      DynamicSupervisor.terminate_child(Catt.GameSupervisor, pid)
    end

    PubSub.broadcast(Catt.PubSub, code, :update)
  end

  @spec start_game(Numeric.t()) :: {:ok, pid()} | {:error, {:already_started, pid()}}
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

    DynamicSupervisor.start_child(__MODULE__, child_spec)

    {:ok, code}
  end

  @spec stop_game(String.t()) :: :ok
  def stop_game(game_id) do
    :ok
  end

  @spec which_children() :: [
          {any(), :restarting | :undefined | pid(), :supervisor | :worker, :dynamic | [atom()]}
        ]
  def which_children do
    Supervisor.which_children(__MODULE__)
  end
end
