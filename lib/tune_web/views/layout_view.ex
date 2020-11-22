defmodule TuneWeb.LayoutView do
  @moduledoc false
  use TuneWeb, :view

  def files do
    {:ok, files} = File.ls("sessions")

    files
    |> Enum.filter(fn file -> file != ".DS_Store" end)
  end
end
