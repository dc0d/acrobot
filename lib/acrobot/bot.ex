defmodule Acrobot.Bot do
  use GenServer
  require Logger

  @moduledoc """
  Our fantastic bot!
  """

  @error_delay  15 # seconds
  @start_delay  5  # seconds
  @rcvd_timeout 30 # seconds

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  ## server callbacks

  def init(state) do
    schedule_updates(0, @start_delay)
    {:ok, state}
  end

  def handle_info({:failed, update}, state) do
    l = state
    state = l ++ [update]
    {:noreply, state}
  end

  def handle_info({:updates, []}, state) do
    schedule_updates(0)
    {:noreply, state}
  end

  def handle_info({:updates, updates}, state) do
    l = state
    {max_id, res} = append_update 0, l, updates

    answer_incoming res

    schedule_updates(max_id + 1)
    # if succeeded, state would be empty list
    state = []
    {:noreply, state}
  end

  def handle_info({:error, msg}, state) do
    Logger.error "#{inspect msg}"
    schedule_updates(0, @error_delay)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.warn "unknown #{inspect msg}"
    schedule_updates(0, @error_delay)
    {:noreply, state}
  end

  ## helpers

  defp answer_incoming([]) do
  end

  defp answer_incoming([h|t]) do
    case get_chat_id(h.message) do
      {:ok, chat_id} ->
        dt = :calendar.local_time()
        Nadia.send_message chat_id, "#{inspect dt}", parse_mode: :html
      err ->
        Logger.error "#{inspect err}"
    end
    answer_incoming t
  end

  defp append_update(max_id, old_list, new_list) do
    res = old_list ++ new_list
    {find_max_id(max_id, res), res}
  end

  defp find_max_id(max_id, []) do
    max_id
  end

  defp find_max_id(max_id, [h|t]) do
    id =
      if h.update_id > max_id do
        h.update_id
      else
        max_id
      end
    find_max_id id, t
  end

  defp schedule_updates(offset, sleep_ms \\ 0) do
    s = self()
    Task.Supervisor.start_child(Acrobot.TaskSupervisor, fn ->
      if sleep_ms > 0 do
        Process.sleep(sleep_ms)
      end

      res = Nadia.get_updates offset: offset, timeout: @rcvd_timeout
      case res do
        {:ok, updates} ->
          send(s, {:updates, updates})
        _ ->
          send s, res
      end
    end)
    # simulating failiure
    # if offset > 3 && (rem offset, 3) == 0 do
    #   1/0
    # end
  end

  defp get_chat_id(%{:chat => %{:id => id}}) when id != nil do
    {:ok, id}
  end

  defp get_chat_id(msg) do
    Logger.warn "unknown #{inspect msg}"
    {:unknown_message}
  end
end
