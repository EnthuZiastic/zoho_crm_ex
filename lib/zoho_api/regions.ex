defmodule ZohoAPI.Regions do
  @moduledoc """
  Zoho data center region configuration.

  Zoho operates multiple data centers worldwide. This module provides
  centralized configuration for region-specific URLs across all Zoho services.

  ## Supported Regions

    - `:in` - India (default)
    - `:com` - United States
    - `:eu` - Europe
    - `:au` - Australia
    - `:jp` - Japan
    - `:uk` - United Kingdom
    - `:ca` - Canada
    - `:sa` - Saudi Arabia

  ## Usage

      # Get OAuth URL for a region
      ZohoAPI.Regions.oauth_url(:eu)
      # => "https://accounts.zoho.eu"

      # Get API URL for a service
      ZohoAPI.Regions.api_url(:zohoapis, :com)
      # => "https://www.zohoapis.com"

      # Validate a region
      ZohoAPI.Regions.valid?(:eu)
      # => true
  """

  @valid_regions [:in, :com, :eu, :au, :jp, :uk, :ca, :sa]

  # OAuth/Accounts URLs for token operations
  @oauth_urls %{
    in: "https://accounts.zoho.in",
    com: "https://accounts.zoho.com",
    eu: "https://accounts.zoho.eu",
    au: "https://accounts.zoho.com.au",
    jp: "https://accounts.zoho.jp",
    uk: "https://accounts.zoho.uk",
    ca: "https://accounts.zohocloud.ca",
    sa: "https://accounts.zoho.sa"
  }

  # API URLs by service
  @api_urls %{
    # Zoho APIs (CRM, Bookings, WorkDrive, Bulk, Composite)
    zohoapis: %{
      in: "https://www.zohoapis.in",
      com: "https://www.zohoapis.com",
      eu: "https://www.zohoapis.eu",
      au: "https://www.zohoapis.com.au",
      jp: "https://www.zohoapis.jp",
      uk: "https://www.zohoapis.uk",
      ca: "https://www.zohoapis.ca",
      sa: "https://www.zohoapis.sa"
    },
    # Zoho Recruit
    recruit: %{
      in: "https://recruit.zoho.in",
      com: "https://recruit.zoho.com",
      eu: "https://recruit.zoho.eu",
      au: "https://recruit.zoho.com.au",
      jp: "https://recruit.zoho.jp",
      uk: "https://recruit.zoho.uk",
      ca: "https://recruit.zohocloud.ca",
      sa: "https://recruit.zoho.sa"
    },
    # Zoho Desk
    desk: %{
      in: "https://desk.zoho.in",
      com: "https://desk.zoho.com",
      eu: "https://desk.zoho.eu",
      au: "https://desk.zoho.com.au",
      jp: "https://desk.zoho.jp",
      uk: "https://desk.zoho.uk",
      ca: "https://desk.zohocloud.ca",
      sa: "https://desk.zoho.sa"
    },
    # Zoho Projects
    projects: %{
      in: "https://projectsapi.zoho.in",
      com: "https://projectsapi.zoho.com",
      eu: "https://projectsapi.zoho.eu",
      au: "https://projectsapi.zoho.com.au",
      jp: "https://projectsapi.zoho.jp",
      uk: "https://projectsapi.zoho.uk",
      ca: "https://projectsapi.zohocloud.ca",
      sa: "https://projectsapi.zoho.sa"
    },
    # Zoho Cliq
    cliq: %{
      in: "https://cliq.zoho.in",
      com: "https://cliq.zoho.com",
      eu: "https://cliq.zoho.eu",
      au: "https://cliq.zoho.com.au",
      jp: "https://cliq.zoho.jp",
      uk: "https://cliq.zoho.uk",
      ca: "https://cliq.zohocloud.ca",
      sa: "https://cliq.zoho.sa"
    }
  }

  @doc """
  Returns the list of valid region atoms.

  ## Examples

      iex> ZohoAPI.Regions.valid_regions()
      [:in, :com, :eu, :au, :jp, :uk, :ca, :sa]
  """
  @spec valid_regions() :: [atom()]
  def valid_regions, do: @valid_regions

  @doc """
  Checks if a region is valid.

  ## Examples

      iex> ZohoAPI.Regions.valid?(:eu)
      true

      iex> ZohoAPI.Regions.valid?(:invalid)
      false
  """
  @spec valid?(atom()) :: boolean()
  def valid?(region), do: region in @valid_regions

  @doc """
  Validates a region and returns it if valid, raises ArgumentError otherwise.

  ## Examples

      iex> ZohoAPI.Regions.validate!(:eu)
      :eu

      iex> ZohoAPI.Regions.validate!(:invalid)
      ** (ArgumentError) Invalid region :invalid. Valid regions are: :in, :com, :eu, :au, :jp, :uk, :ca, :sa
  """
  @spec validate!(atom()) :: atom()
  def validate!(region) do
    if valid?(region) do
      region
    else
      raise ArgumentError,
        message:
          "Invalid region #{inspect(region)}. Valid regions are: #{Enum.join(@valid_regions, ", ")}"
    end
  end

  @doc """
  Returns the OAuth/Accounts URL for a region.

  Used for token operations (refresh, authorize, etc.).

  ## Examples

      iex> ZohoAPI.Regions.oauth_url(:in)
      "https://accounts.zoho.in"

      iex> ZohoAPI.Regions.oauth_url(:eu)
      "https://accounts.zoho.eu"
  """
  @spec oauth_url(atom()) :: String.t()
  def oauth_url(region) do
    Map.get(@oauth_urls, region, @oauth_urls[:in])
  end

  @doc """
  Returns the API URL for a service in a specific region.

  ## Services

    - `:zohoapis` - CRM, Bookings, WorkDrive, Bulk, Composite APIs
    - `:recruit` - Zoho Recruit
    - `:desk` - Zoho Desk
    - `:projects` - Zoho Projects

  ## Examples

      iex> ZohoAPI.Regions.api_url(:zohoapis, :com)
      "https://www.zohoapis.com"

      iex> ZohoAPI.Regions.api_url(:desk, :eu)
      "https://desk.zoho.eu"
  """
  @spec api_url(atom(), atom()) :: String.t()
  def api_url(service, region) do
    @api_urls
    |> Map.get(service, @api_urls[:zohoapis])
    |> Map.get(region, @api_urls[:zohoapis][:in])
  end
end
