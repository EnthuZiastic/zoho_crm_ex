defmodule ZohoCrm.Modules.WorkDrive.FilesTest do
  use ExUnit.Case, async: true

  import Mox

  alias ZohoCrm.InputRequest
  alias ZohoCrm.Modules.WorkDrive.Files

  setup :verify_on_exit!

  describe "list_files/2" do
    test "lists files in a folder" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, headers ->
        assert url =~ "workdrive/api/v1/files/folder_123/files"
        assert {"Authorization", "Zoho-oauthtoken test_token"} in headers

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "file_1"}]})
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = Files.list_files(input, "folder_123")

      assert result["data"] == [%{"id" => "file_1"}]
    end
  end

  describe "get_file/2" do
    test "gets file details" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "files/file_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "data" => %{"id" => "file_123", "attributes" => %{"name" => "test.pdf"}}
             })
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, result} = Files.get_file(input, "file_123")

      assert result["data"]["attributes"]["name"] == "test.pdf"
    end
  end

  describe "download_file/2" do
    test "downloads file content" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "download/file_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "binary file content"
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, content} = Files.download_file(input, "file_123")

      assert content == "binary file content"
    end
  end

  describe "rename_file/2" do
    test "renames a file" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :patch, url, body, _headers ->
        assert url =~ "files/file_123"
        body_map = Jason.decode!(body)
        assert body_map["data"]["attributes"]["name"] == "renamed.pdf"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => %{"id" => "file_123"}})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "data" => %{
            "attributes" => %{"name" => "renamed.pdf"},
            "type" => "files"
          }
        })

      {:ok, result} = Files.rename_file(input, "file_123")

      assert result["data"]["id"] == "file_123"
    end
  end

  describe "move_file/2" do
    test "moves a file to another folder" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :patch, url, body, _headers ->
        assert url =~ "files/file_123"
        body_map = Jason.decode!(body)
        assert body_map["data"]["attributes"]["parent_id"] == "new_folder"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => %{"id" => "file_123"}})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "data" => %{
            "attributes" => %{"parent_id" => "new_folder"},
            "type" => "files"
          }
        })

      {:ok, result} = Files.move_file(input, "file_123")

      assert result["data"]["id"] == "file_123"
    end
  end

  describe "copy_file/2" do
    test "copies a file to another folder" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :post, url, _body, _headers ->
        assert url =~ "files/file_123/copy"

        {:ok,
         %HTTPoison.Response{
           status_code: 201,
           body: Jason.encode!(%{"data" => %{"id" => "file_copy"}})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_body(%{
          "data" => %{
            "attributes" => %{"parent_id" => "dest_folder"},
            "type" => "files"
          }
        })

      {:ok, result} = Files.copy_file(input, "file_123")

      assert result["data"]["id"] == "file_copy"
    end
  end

  describe "delete_file/2" do
    test "deletes a file" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :delete, url, _body, _headers ->
        assert url =~ "files/file_123"

        {:ok,
         %HTTPoison.Response{
           status_code: 204,
           body: ""
         }}
      end)

      input = InputRequest.new("test_token")
      {:ok, _result} = Files.delete_file(input, "file_123")
    end
  end

  describe "search_files/1" do
    test "searches for files" do
      expect(ZohoCrm.HTTPClientMock, :request, fn :get, url, _body, _headers ->
        assert url =~ "files/search"
        assert url =~ "search_string=report"

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"data" => [%{"id" => "file_1"}]})
         }}
      end)

      input =
        InputRequest.new("test_token")
        |> InputRequest.with_query_params(%{search_string: "report"})

      {:ok, result} = Files.search_files(input)

      assert length(result["data"]) == 1
    end
  end
end
