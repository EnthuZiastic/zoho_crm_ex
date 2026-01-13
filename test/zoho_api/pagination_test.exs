defmodule ZohoAPI.PaginationTest do
  use ExUnit.Case, async: true

  alias ZohoAPI.InputRequest
  alias ZohoAPI.Pagination

  describe "stream_all/3" do
    test "streams records from single page" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:ok,
         %{
           "data" => [%{"id" => "1"}, %{"id" => "2"}],
           "info" => %{"more_records" => false, "page" => 1}
         }}
      end

      records = Pagination.stream_all(input, fetch_fn) |> Enum.to_list()

      assert length(records) == 2
      assert Enum.map(records, & &1["id"]) == ["1", "2"]
    end

    test "streams records from multiple pages" do
      input = InputRequest.new("test_token")

      fetch_fn = fn input ->
        page = Map.get(input.query_params || %{}, "page", 1)

        case page do
          1 ->
            {:ok,
             %{
               "data" => [%{"id" => "1"}, %{"id" => "2"}],
               "info" => %{"more_records" => true, "page" => 1}
             }}

          2 ->
            {:ok,
             %{
               "data" => [%{"id" => "3"}, %{"id" => "4"}],
               "info" => %{"more_records" => true, "page" => 2}
             }}

          3 ->
            {:ok,
             %{
               "data" => [%{"id" => "5"}],
               "info" => %{"more_records" => false, "page" => 3}
             }}
        end
      end

      records = Pagination.stream_all(input, fetch_fn) |> Enum.to_list()

      assert length(records) == 5
      assert Enum.map(records, & &1["id"]) == ["1", "2", "3", "4", "5"]
    end

    test "respects max_records option" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:ok,
         %{
           "data" => [%{"id" => "1"}, %{"id" => "2"}, %{"id" => "3"}],
           "info" => %{"more_records" => true, "page" => 1}
         }}
      end

      records = Pagination.stream_all(input, fetch_fn, max_records: 2) |> Enum.to_list()

      assert length(records) == 2
    end

    test "handles empty data response" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:ok, %{"data" => [], "info" => %{"more_records" => false}}}
      end

      records = Pagination.stream_all(input, fetch_fn) |> Enum.to_list()

      assert records == []
    end

    test "handles response without info block" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:ok, %{"data" => [%{"id" => "1"}]}}
      end

      records = Pagination.stream_all(input, fetch_fn) |> Enum.to_list()

      assert length(records) == 1
    end

    test "handles direct list response" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:ok, [%{"id" => "1"}, %{"id" => "2"}]}
      end

      records = Pagination.stream_all(input, fetch_fn) |> Enum.to_list()

      assert length(records) == 2
    end

    test "can take partial results with Enum.take" do
      input = InputRequest.new("test_token")
      counter = :counters.new(1, [:atomics])

      fetch_fn = fn _input ->
        :counters.add(counter, 1, 1)

        {:ok,
         %{
           "data" => [%{"id" => "1"}, %{"id" => "2"}, %{"id" => "3"}],
           "info" => %{"more_records" => true}
         }}
      end

      # Only take 2 records
      records = Pagination.stream_all(input, fetch_fn) |> Enum.take(2)

      assert length(records) == 2
      # Should only fetch one page
      assert :counters.get(counter, 1) == 1
    end

    test "raises on fetch error" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:error, "API error"}
      end

      assert_raise RuntimeError, ~r/Failed to fetch page/, fn ->
        Pagination.stream_all(input, fetch_fn) |> Enum.to_list()
      end
    end
  end

  describe "fetch_all/3" do
    test "fetches all records" do
      input = InputRequest.new("test_token")

      fetch_fn = fn input ->
        page = Map.get(input.query_params || %{}, "page", 1)

        case page do
          1 ->
            {:ok,
             %{
               "data" => [%{"id" => "1"}],
               "info" => %{"more_records" => true}
             }}

          2 ->
            {:ok,
             %{
               "data" => [%{"id" => "2"}],
               "info" => %{"more_records" => false}
             }}
        end
      end

      assert {:ok, records} = Pagination.fetch_all(input, fetch_fn)
      assert length(records) == 2
    end

    test "returns error on fetch failure" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:error, "API error"}
      end

      assert {:error, _} = Pagination.fetch_all(input, fetch_fn)
    end

    test "respects max_records option" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:ok,
         %{
           "data" => [%{"id" => "1"}, %{"id" => "2"}, %{"id" => "3"}],
           "info" => %{"more_records" => true}
         }}
      end

      assert {:ok, records} = Pagination.fetch_all(input, fetch_fn, max_records: 2)
      assert length(records) == 2
    end
  end

  describe "fetch_page/4" do
    test "fetches single page with pagination params" do
      input = InputRequest.new("test_token")

      fetch_fn = fn input ->
        assert input.query_params["page"] == 2
        assert input.query_params["per_page"] == 50

        {:ok,
         %{
           "data" => [%{"id" => "1"}],
           "info" => %{"more_records" => true}
         }}
      end

      assert {:ok, [%{"id" => "1"}], true} = Pagination.fetch_page(input, fetch_fn, 2, 50)
    end

    test "returns more_records=false for last page" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:ok,
         %{
           "data" => [%{"id" => "1"}],
           "info" => %{"more_records" => false}
         }}
      end

      assert {:ok, _, false} = Pagination.fetch_page(input, fetch_fn, 1, 50)
    end

    test "preserves existing query params" do
      input =
        InputRequest.new("test_token")
        |> InputRequest.with_query_params(%{"fields" => "id,name"})

      fetch_fn = fn input ->
        assert input.query_params["fields"] == "id,name"
        assert input.query_params["page"] == 1

        {:ok, %{"data" => []}}
      end

      Pagination.fetch_page(input, fetch_fn, 1, 50)
    end

    test "returns error on failure" do
      input = InputRequest.new("test_token")

      fetch_fn = fn _input ->
        {:error, "Network error"}
      end

      assert {:error, "Network error"} = Pagination.fetch_page(input, fetch_fn, 1, 50)
    end
  end
end
