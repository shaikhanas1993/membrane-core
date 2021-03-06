defmodule Membrane.Element.Base.Mixin.SourceBehaviour do
  @moduledoc """
  Module defining behaviour for source and filter elements.

  When used declares behaviour implementation, provides default callback definitions
  and imports macros.

  For more information on implementing elements, see `Membrane.Element.Base`.
  """

  alias Membrane.{Buffer, Element}
  alias Membrane.Core.Element.PadsSpecsParser
  alias Element.{CallbackContext, Pad}
  alias Element.Base.Mixin.CommonBehaviour

  @doc """
  Callback called when buffers should be emitted by a source or filter.

  It is called only for output pads in the pull mode, as in their case demand
  is triggered by the input pad of the subsequent element.

  In sources, appropriate amount of data should be sent here.

  In filters, this callback should usually return `:demand` action with
  size sufficient for supplying incoming demand. This will result in calling
  `c:Membrane.Element.Base.Filter.handle_process_list/4`, which is to supply
  the demand.

  If a source is unable to produce enough buffers, or a filter underestimated
  returned demand, the `:redemand` action should be used (see
  `t:Membrane.Element.Action.redemand_t/0`).
  """
  @callback handle_demand(
              pad :: Pad.ref_t(),
              size :: non_neg_integer,
              unit :: Buffer.Metric.unit_t(),
              context :: CallbackContext.Demand.t(),
              state :: Element.state_t()
            ) :: CommonBehaviour.callback_return_t()

  @doc """
  Macro that defines output pads for the element.

  Allows to use `one_of/1` and `range/2` functions from `Membrane.Caps.Matcher`
  without module prefix.

  It automatically generates documentation from the given definition
  and adds compile-time caps specs validation.

  The type `t:Membrane.Element.Pad.output_spec_t/0` describes how the definition of pads should look.
  """
  defmacro def_output_pads(pads) do
    PadsSpecsParser.def_pads(pads, :output)
  end

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      import unquote(__MODULE__), only: [def_output_pads: 1]
    end
  end
end
