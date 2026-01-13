defmodule ZohoAPI.Modules.TokenTest do
  use ExUnit.Case, async: true

  alias ZohoAPI.Modules.Token

  describe "oauth_url/1" do
    test "returns correct URL for India region" do
      assert Token.oauth_url(:in) == "https://accounts.zoho.in"
    end

    test "returns correct URL for US region" do
      assert Token.oauth_url(:com) == "https://accounts.zoho.com"
    end

    test "returns correct URL for EU region" do
      assert Token.oauth_url(:eu) == "https://accounts.zoho.eu"
    end

    test "returns correct URL for Australia region" do
      assert Token.oauth_url(:au) == "https://accounts.zoho.com.au"
    end

    test "returns correct URL for Japan region" do
      assert Token.oauth_url(:jp) == "https://accounts.zoho.jp"
    end

    test "returns correct URL for UK region" do
      assert Token.oauth_url(:uk) == "https://accounts.zoho.uk"
    end

    test "returns correct URL for Canada region" do
      assert Token.oauth_url(:ca) == "https://accounts.zohocloud.ca"
    end

    test "returns correct URL for Saudi Arabia region" do
      assert Token.oauth_url(:sa) == "https://accounts.zoho.sa"
    end

    test "returns default URL for unknown region" do
      assert Token.oauth_url(:unknown) == "https://accounts.zoho.in"
    end
  end

  describe "refresh_access_token/2" do
    test "returns error for non-string refresh token" do
      assert {:error, "INVALID_REFRESH_TOKEN"} = Token.refresh_access_token(123)
      assert {:error, "INVALID_REFRESH_TOKEN"} = Token.refresh_access_token(nil)
    end
  end
end
