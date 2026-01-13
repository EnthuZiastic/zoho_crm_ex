defmodule ZohoAPITest do
  use ExUnit.Case
  doctest ZohoAPI

  test "greets the world" do
    assert ZohoAPI.hello() == :world
  end
end
