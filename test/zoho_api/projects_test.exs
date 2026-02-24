defmodule ZohoAPI.ProjectsTest do
  use ExUnit.Case, async: false

  import Mox

  alias ZohoAPI.Projects
  alias ZohoAPI.TokenCache

  setup :verify_on_exit!

  setup do
    name = :"projects_test_#{:rand.uniform(100_000)}"
    {:ok, pid} = TokenCache.start_link(name: name)

    prev_config = Application.get_env(:zoho_api, :token_cache, [])
    Application.put_env(:zoho_api, :token_cache, name: name)

    on_exit(fn ->
      Application.put_env(:zoho_api, :token_cache, prev_config)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    TokenCache.put_token(:projects, "test_projects_token")
    Process.sleep(10)

    :ok
  end

  describe "create_task/3" do
    test "returns {:ok, task_id} as string when response has integer id" do
      expect(ZohoAPI.HTTPClientMock, :request, fn _method, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"tasks" => [%{"id" => 42, "name" => "Task One"}]})
         }}
      end)

      assert {:ok, "42"} = Projects.create_task("portal_1", "project_1", %{name: "Task One"})
    end

    test "returns {:ok, task_id} as string when response has string id" do
      expect(ZohoAPI.HTTPClientMock, :request, fn _method, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"tasks" => [%{"id" => "abc", "name" => "Task Two"}]})
         }}
      end)

      assert {:ok, "abc"} = Projects.create_task("portal_1", "project_1", %{name: "Task Two"})
    end

    test "returns {:error, other} on unexpected response shape" do
      expect(ZohoAPI.HTTPClientMock, :request, fn _method, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"error" => "Something went wrong"})
         }}
      end)

      assert {:error, _} = Projects.create_task("portal_1", "project_1", %{name: "Bad"})
    end
  end

  describe "update_task/4" do
    test "returns {:ok, task_id} as string when response has integer id (no crash)" do
      expect(ZohoAPI.HTTPClientMock, :request, fn _method, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"tasks" => [%{"id" => 99}]})
         }}
      end)

      assert {:ok, "99"} =
               Projects.update_task("portal_1", "project_1", "task_1", %{name: "Updated"})
    end

    test "returns {:ok, task_id} as string when response has string id" do
      expect(ZohoAPI.HTTPClientMock, :request, fn _method, _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"tasks" => [%{"id" => "xyz"}]})
         }}
      end)

      assert {:ok, "xyz"} =
               Projects.update_task("portal_1", "project_1", "task_1", %{name: "Updated"})
    end
  end
end
