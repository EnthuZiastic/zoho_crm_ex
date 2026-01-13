defmodule ZohoAPI.ValidationTest do
  use ExUnit.Case, async: true

  alias ZohoAPI.Validation

  describe "validate_id/1" do
    test "accepts valid alphanumeric IDs" do
      assert :ok = Validation.validate_id("12345")
      assert :ok = Validation.validate_id("abc123")
      assert :ok = Validation.validate_id("ABC123xyz")
    end

    test "accepts IDs with underscores and hyphens" do
      assert :ok = Validation.validate_id("abc_123")
      assert :ok = Validation.validate_id("abc-123")
      assert :ok = Validation.validate_id("abc_123-xyz")
    end

    test "rejects path traversal attempts" do
      assert {:error, "Invalid ID: path traversal not allowed"} =
               Validation.validate_id("../admin")

      assert {:error, "Invalid ID: path traversal not allowed"} =
               Validation.validate_id("..\\admin")

      assert {:error, "Invalid ID: path traversal not allowed"} =
               Validation.validate_id("foo/../bar")
    end

    test "rejects IDs with path separators" do
      assert {:error, "Invalid ID: path separators not allowed"} =
               Validation.validate_id("foo/bar")

      assert {:error, "Invalid ID: path separators not allowed"} =
               Validation.validate_id("foo\\bar")
    end

    test "rejects empty IDs" do
      assert {:error, "ID cannot be empty"} = Validation.validate_id("")
      assert {:error, "ID cannot be empty"} = Validation.validate_id("   ")
    end

    test "rejects IDs with special characters" do
      assert {:error, _} = Validation.validate_id("id@123")
      assert {:error, _} = Validation.validate_id("id#123")
      assert {:error, _} = Validation.validate_id("id$123")
      assert {:error, _} = Validation.validate_id("id%123")
    end

    test "rejects non-string IDs" do
      assert {:error, "ID must be a string"} = Validation.validate_id(123)
      assert {:error, "ID must be a string"} = Validation.validate_id(nil)
      assert {:error, "ID must be a string"} = Validation.validate_id(%{})
    end
  end
end
