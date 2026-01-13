defmodule ZohoAPI.RetryTest do
  use ExUnit.Case, async: true

  alias ZohoAPI.Retry

  describe "with_retry/2" do
    test "executes function successfully without retry" do
      result = Retry.with_retry(fn -> {:ok, 200, %{"data" => "success"}} end)
      assert result == {:ok, 200, %{"data" => "success"}}
    end

    test "retries on network timeout error" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            current = :counters.get(counter, 1)

            if current < 3 do
              {:error, :timeout}
            else
              {:ok, 200, %{"data" => "success"}}
            end
          end,
          max_retries: 3,
          base_delay_ms: 1
        )

      assert result == {:ok, 200, %{"data" => "success"}}
      assert :counters.get(counter, 1) == 3
    end

    test "retries on 500 server error" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            current = :counters.get(counter, 1)

            if current < 2 do
              {:ok, 500, %{"error" => "server error"}}
            else
              {:ok, 200, %{"data" => "success"}}
            end
          end,
          max_retries: 3,
          base_delay_ms: 1
        )

      assert result == {:ok, 200, %{"data" => "success"}}
      assert :counters.get(counter, 1) == 2
    end

    test "does not retry on 400 client error" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:ok, 400, %{"error" => "bad request"}}
          end,
          max_retries: 3,
          base_delay_ms: 1
        )

      assert result == {:ok, 400, %{"error" => "bad request"}}
      # Should only be called once, no retries
      assert :counters.get(counter, 1) == 1
    end

    test "does not retry on 401 unauthorized" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:ok, 401, %{"error" => "unauthorized"}}
          end,
          max_retries: 3,
          base_delay_ms: 1
        )

      assert result == {:ok, 401, %{"error" => "unauthorized"}}
      assert :counters.get(counter, 1) == 1
    end

    test "respects max_retries limit" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, :timeout}
          end,
          max_retries: 2,
          base_delay_ms: 1
        )

      assert result == {:error, :timeout}
      # Initial call + 2 retries = 3 total calls
      assert :counters.get(counter, 1) == 3
    end

    test "disabled retry executes once" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            {:error, :timeout}
          end,
          enabled: false
        )

      assert result == {:error, :timeout}
      assert :counters.get(counter, 1) == 1
    end

    test "retries on 429 rate limit error" do
      counter = :counters.new(1, [:atomics])

      result =
        Retry.with_retry(
          fn ->
            :counters.add(counter, 1, 1)
            current = :counters.get(counter, 1)

            if current < 2 do
              {:ok, 429, %{"error" => "rate limited"}}
            else
              {:ok, 200, %{"data" => "success"}}
            end
          end,
          max_retries: 3,
          base_delay_ms: 1
        )

      assert result == {:ok, 200, %{"data" => "success"}}
      assert :counters.get(counter, 1) == 2
    end
  end

  describe "calculate_delay/4" do
    test "calculates exponential delay" do
      # First retry (attempt 0)
      delay0 = Retry.calculate_delay(0, 1000, 30_000, false)
      assert delay0 == 1000

      # Second retry (attempt 1) = 2^1 * 1000 = 2000
      delay1 = Retry.calculate_delay(1, 1000, 30_000, false)
      assert delay1 == 2000

      # Third retry (attempt 2) = 2^2 * 1000 = 4000
      delay2 = Retry.calculate_delay(2, 1000, 30_000, false)
      assert delay2 == 4000
    end

    test "respects max delay limit" do
      # Large attempt would exceed max
      delay = Retry.calculate_delay(10, 1000, 5000, false)
      assert delay == 5000
    end

    test "adds jitter when enabled" do
      # With jitter enabled, delay should be >= base delay
      delay = Retry.calculate_delay(0, 1000, 30_000, true)
      assert delay >= 1000
      # Jitter adds up to 30%
      assert delay <= 1300
    end
  end

  describe "retry behavior verification" do
    test "network errors trigger retry" do
      # Verified by the with_retry tests above - network errors like :timeout are retried
    end

    test "5xx status codes trigger retry" do
      # Verified by the "retries on 500 server error" test above
    end

    test "429 rate limit triggers retry" do
      # Verified by the "retries on 429 rate limit error" test above
    end

    test "4xx client errors do not trigger retry" do
      # Verified by the "does not retry on 400 client error" and "does not retry on 401" tests above
    end
  end
end
