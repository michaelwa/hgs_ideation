defmodule HgsIdeationWeb.PageController do
  use HgsIdeationWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
