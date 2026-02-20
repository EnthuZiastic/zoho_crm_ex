defmodule ZohoAPI.RegionsTest do
  use ExUnit.Case, async: true

  alias ZohoAPI.Regions

  describe "valid_regions/0" do
    test "returns list of all valid regions" do
      regions = Regions.valid_regions()

      assert :in in regions
      assert :com in regions
      assert :eu in regions
      assert :au in regions
      assert :jp in regions
      assert :uk in regions
      assert :ca in regions
      assert :sa in regions
      assert length(regions) == 8
    end
  end

  describe "valid?/1" do
    test "returns true for valid regions" do
      assert Regions.valid?(:in)
      assert Regions.valid?(:com)
      assert Regions.valid?(:eu)
      assert Regions.valid?(:au)
      assert Regions.valid?(:jp)
      assert Regions.valid?(:uk)
      assert Regions.valid?(:ca)
      assert Regions.valid?(:sa)
    end

    test "returns false for invalid regions" do
      refute Regions.valid?(:invalid)
      refute Regions.valid?(:us)
      refute Regions.valid?(:china)
    end
  end

  describe "validate!/1" do
    test "returns region atom for valid regions" do
      assert Regions.validate!(:in) == :in
      assert Regions.validate!(:com) == :com
      assert Regions.validate!(:eu) == :eu
    end

    test "raises ArgumentError with helpful message for invalid regions" do
      assert_raise ArgumentError, ~r/Invalid region :invalid/, fn ->
        Regions.validate!(:invalid)
      end

      assert_raise ArgumentError, ~r/Valid regions are:/, fn ->
        Regions.validate!(:unknown)
      end
    end
  end

  describe "oauth_url/1" do
    test "returns correct OAuth URL for India" do
      assert Regions.oauth_url(:in) == "https://accounts.zoho.in"
    end

    test "returns correct OAuth URL for US" do
      assert Regions.oauth_url(:com) == "https://accounts.zoho.com"
    end

    test "returns correct OAuth URL for EU" do
      assert Regions.oauth_url(:eu) == "https://accounts.zoho.eu"
    end

    test "returns correct OAuth URL for Australia" do
      assert Regions.oauth_url(:au) == "https://accounts.zoho.com.au"
    end

    test "returns correct OAuth URL for Japan" do
      assert Regions.oauth_url(:jp) == "https://accounts.zoho.jp"
    end

    test "returns correct OAuth URL for UK" do
      assert Regions.oauth_url(:uk) == "https://accounts.zoho.uk"
    end

    test "returns correct OAuth URL for Canada" do
      assert Regions.oauth_url(:ca) == "https://accounts.zohocloud.ca"
    end

    test "returns correct OAuth URL for Saudi Arabia" do
      assert Regions.oauth_url(:sa) == "https://accounts.zoho.sa"
    end

    test "returns default URL for unknown region" do
      assert Regions.oauth_url(:unknown) == "https://accounts.zoho.in"
    end
  end

  describe "api_url/2" do
    test "returns correct zohoapis URL for different regions" do
      assert Regions.api_url(:zohoapis, :in) == "https://www.zohoapis.in"
      assert Regions.api_url(:zohoapis, :com) == "https://www.zohoapis.com"
      assert Regions.api_url(:zohoapis, :eu) == "https://www.zohoapis.eu"
      assert Regions.api_url(:zohoapis, :au) == "https://www.zohoapis.com.au"
      assert Regions.api_url(:zohoapis, :jp) == "https://www.zohoapis.jp"
      assert Regions.api_url(:zohoapis, :uk) == "https://www.zohoapis.uk"
      assert Regions.api_url(:zohoapis, :ca) == "https://www.zohoapis.ca"
      assert Regions.api_url(:zohoapis, :sa) == "https://www.zohoapis.sa"
    end

    test "returns correct recruit URL for different regions" do
      assert Regions.api_url(:recruit, :in) == "https://recruit.zoho.in"
      assert Regions.api_url(:recruit, :com) == "https://recruit.zoho.com"
      assert Regions.api_url(:recruit, :eu) == "https://recruit.zoho.eu"
      assert Regions.api_url(:recruit, :ca) == "https://recruit.zohocloud.ca"
    end

    test "returns correct desk URL for different regions" do
      assert Regions.api_url(:desk, :in) == "https://desk.zoho.in"
      assert Regions.api_url(:desk, :com) == "https://desk.zoho.com"
      assert Regions.api_url(:desk, :eu) == "https://desk.zoho.eu"
      assert Regions.api_url(:desk, :ca) == "https://desk.zohocloud.ca"
    end

    test "returns correct projects URL for different regions" do
      assert Regions.api_url(:projects, :in) == "https://projectsapi.zoho.in"
      assert Regions.api_url(:projects, :com) == "https://projectsapi.zoho.com"
      assert Regions.api_url(:projects, :eu) == "https://projectsapi.zoho.eu"
      assert Regions.api_url(:projects, :ca) == "https://projectsapi.zohocloud.ca"
    end

    test "returns default URL for unknown service" do
      assert Regions.api_url(:unknown_service, :in) == "https://www.zohoapis.in"
    end

    test "returns default URL for unknown region" do
      assert Regions.api_url(:zohoapis, :unknown) == "https://www.zohoapis.in"
    end
  end
end
