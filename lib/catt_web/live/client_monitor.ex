defmodule Catt.GameClientMonitor do
  use GenServer
  require Logger

  def monitor(pid, view_module, meta) do
    GenServer.call(Catt.GameClientMonitor, {:monitor, pid, view_module, meta})
  end

  def init(_) do
    Logger.info("GCM starting")
    {:ok, %{views: %{}}}
  end

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  def handle_call({:monitor, pid, view_module, meta}, _, %{views: views} = state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | views: Map.put(views, pid, {view_module, meta})}}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    {{module, meta}, new_views} = Map.pop(state.views, pid)
    module.unmount(reason, meta)
    {:noreply, %{state | views: new_views}}
  end
end
