defmodule ZohoCrm.Modules.WorkDrive.FoldersTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoCrm.InputRequest
  alias ZohoCrm.Modules.WorkDrive.Folders

  setup :verify_on_exit!

  describe "list_team_folders/2" do
    test "lists team folders" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, headers ->
        assert url =~ "workdrive/api/v1/teams/team_123/teamfolders"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "folder_1"}]})
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = Folders.list_team_folders(input, "team_123")

      assert result["data"] == [%{"id" => "folder_1"}]
    end
  end

  describe "list_folders/2" do
    test "lists folders within a parent folder" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "files/folder_123/files"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "subfolder_1"}]})
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = Folders.list_folders(input, "folder_123")

      assert length(result["data"]) == 1
    end
  end

  describe "get_folder/2" do
    test "gets folder details" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "files/folder_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "data" => %{"id" => "folder_123", "attributes" => %{"name" => "Test"}}
             })
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = Folders.get_folder(input, "folder_123")

      assert result["data"]["attributes"]["name"] == "Test"
    end
  end

  describe "create_folder/1" do
    test "creates a new folder" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :post, url, body, _headers ->
        assert url =~ "workdrive/api/v1/files"
        body_map = Jason.decode!(body)
        assert body_map["data"]["attributes"]["name"] == "New Folder"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body: Jason.encode!(%{"data" => %{"id" => "new_folder"}})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "data" => %{
            "attributes" => %{"name" => "New Folder", "parent_id" => "parent_123"},
            "type" => "files"
          }
        })

      {:ok, result} = Folders.create_folder(input)

      assert result["data"]["id"] == "new_folder"
    end
  end

  describe "delete_folder/2" do
    test "deletes a folder" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :delete, url, _body, _headers ->
        assert url =~ "files/folder_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 204,
           body: ""
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, _result} = Folders.delete_folder(input, "folder_123")
    end
  end
end
