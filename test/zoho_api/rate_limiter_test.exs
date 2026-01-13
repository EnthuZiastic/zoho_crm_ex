defmodule ZohoAPI.RateLimiterTest do
  use ExUnit.Case, async: true

  alias ZohoAPI.RateLimiter

  describe "execute/2" do
    test "executes function directly when disabled" do
      counter = :counters.new(1, [:atomics])

      result =
        RateLimiter.execute(
          fn ->
            :counters.add(counter, 1, 1)
            {:ok, "success"}
          end,
          enabled: false
        )

      assert result == {:ok, "success"}
      assert :counters.get(counter, 1) == 1
    end

    test "executes function directly when repo not configured" do
      counter = :counters.new(1, [:atomics])

      result =
        RateLimiter.execute(
          fn ->
            :counters.add(counter, 1, 1)
            {:ok, "success"}
          end,
          enabled: true,
          repo: nil
        )

      assert result == {:ok, "success"}
      assert :counters.get(counter, 1) == 1
    end

    test "executes function directly when rate_limiter not available" do
      # RateLimiter library is not installed in test env
      counter = :counters.new(1, [:atomics])

      result =
        RateLimiter.execute(
          fn ->
            :counters.add(counter, 1, 1)
            {:ok, "success"}
          end,
          enabled: true,
          repo: SomeRepo
        )

      assert result == {:ok, "success"}
      assert :counters.get(counter, 1) == 1
    end
  end

  describe "available?/0" do
    test "returns false when not configured" do
      # Default config has enabled: false
      refute RateLimiter.available?()
    end
  end

  describe "get_config/1" do
    test "returns default configuration" do
      config = RateLimiter.get_config()

      assert config.enabled == false
      assert config.repo == nil
      assert config.key == "zoho_api"
      assert config.request_count == 100
      assert config.time_window == 60
      assert config.safety_margin == 0.2
      assert config.max_retries == 3
    end

    test "merges provided options" do
      config = RateLimiter.get_config(key: "custom_key", request_count: 50)

      assert config.key == "custom_key"
      assert config.request_count == 50
      # Other defaults preserved
      assert config.time_window == 60
    end
  end
end
