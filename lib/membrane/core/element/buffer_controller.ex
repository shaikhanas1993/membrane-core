defmodule Membrane.Core.Element.BufferController do
  @moduledoc false
  # Module handling buffers incoming through input pads.

  alias Membrane.{Buffer, Core, Element}
  alias Core.{CallbackHandler, InputBuffer}
  alias Element.{CallbackContext, Pad}
  alias Core.Element.{ActionHandler, DemandHandler, PadModel, State}
  require CallbackContext.{Process, Write}
  require PadModel
  use Core.Element.Log
  use Bunch

  @doc """
  Handles incoming buffer: either stores it in InputBuffer, or executes element's
  callback. Also calls `Membrane.Core.Element.DemandHandler.check_and_handle_demands/2`
  to check if there are any unsupplied demands.
  """
  @spec handle_buffer(Pad.ref_t(), [Buffer.t()] | Buffer.t(), State.t()) :: State.stateful_try_t()
  def handle_buffer(pad_ref, buffers, state) do
    PadModel.assert_data!(state, pad_ref, %{direction: :input})

    case PadModel.get_data!(state, pad_ref, :mode) do
      :pull -> handle_buffer_pull(pad_ref, buffers, state)
      :push -> exec_buffer_handler(pad_ref, buffers, state)
    end
  end

  @doc """
  Executes `handle_process` or `handle_write_list` callback.
  """
  @spec exec_buffer_handler(
          Pad.ref_t(),
          [Buffer.t()] | Buffer.t(),
          params :: map,
          State.t()
        ) :: State.stateful_try_t()
  def exec_buffer_handler(pad_ref, buffers, params \\ %{}, state)

  def exec_buffer_handler(pad_ref, buffers, params, %State{type: :filter} = state) do
    context = CallbackContext.Process.from_state(state)

    CallbackHandler.exec_and_handle_callback(
      :handle_process_list,
      ActionHandler,
      params,
      [pad_ref, buffers, context],
      state
    )
    |> or_warn_error("Error while handling process")
  end

  def exec_buffer_handler(pad_ref, buffers, params, %State{type: :sink} = state) do
    context = CallbackContext.Write.from_state(state)

    CallbackHandler.exec_and_handle_callback(
      :handle_write_list,
      ActionHandler,
      params,
      [pad_ref, buffers, context],
      state
    )
    |> or_warn_error("Error while handling write")
  end

  @spec handle_buffer_pull(Pad.ref_t(), [Buffer.t()] | Buffer.t(), State.t()) ::
          State.stateful_try_t()
  defp handle_buffer_pull(pad_ref, buffers, state) do
    PadModel.assert_data!(state, pad_ref, %{direction: :input})

    with {:ok, old_pb} <- PadModel.get_data(state, pad_ref, :buffer),
         {:ok, pb} <- old_pb |> InputBuffer.store(buffers) do
      state = PadModel.set_data!(state, pad_ref, :buffer, pb)

      if old_pb |> InputBuffer.empty?() do
        DemandHandler.supply_demand(pad_ref, state)
      else
        {:ok, state}
      end
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end
end
