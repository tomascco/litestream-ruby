# frozen_string_literal: true

require "test_helper"

class TestLitestream < Minitest::Test
  def teardown
    Litestream.systemctl_command = nil
    Litestream.socket = nil
  end

  def test_that_it_has_a_version_number
    refute_nil ::Litestream::VERSION
  end

  def test_replicate_process
    stubbed_info = {"version" => "0.5.8", "pid" => 12_345, "uptime_seconds" => 3600,
                    "started_at" => "2026-02-25T10:00:00Z"}
    Litestream::IPC.stub :info, stubbed_info do
      info = Litestream.replicate_process

      assert_equal info[:status], "running"
      assert_equal info[:pid], 12_345
      assert_equal info[:started].class, DateTime
    end
  end

  def test_databases
    stubbed_list = {
      "databases" => [
        {"path" => "/var/lib/db1", "status" => "active", "last_sync_at" => "2026-02-25T10:00:00Z"},
        {"path" => "/var/lib/db2", "status" => "active", "last_sync_at" => "2026-02-25T09:00:00Z"}
      ]
    }
    stubbed_ltx = [
      {"min_txid" => "0000000000000001", "max_txid" => "0000000000000010", "size" => 4096,
       "created" => "2026-02-25T10:00:00Z", "level" => "0"},
      {"min_txid" => "0000000000000011", "max_txid" => "0000000000000020", "size" => 8192,
       "created" => "2026-02-25T09:00:00Z", "level" => "1"}
    ]

    Litestream::IPC.stub :list, stubbed_list do
      Litestream::Commands.stub :ltx, stubbed_ltx do
        databases = Litestream.databases

        assert_equal databases.size, 2
        assert_equal databases[0]["path"], "/var/lib/db1"
        assert_equal databases[0]["status"], "active"
        assert_equal databases[0]["ltx"], stubbed_ltx
      end
    end
  end

  def test_socket_default
    Litestream.socket = nil
    assert_equal Litestream.socket, "/var/run/litestream.sock"
  end

  def test_socket_custom
    Litestream.socket = "/tmp/my-litestream.sock"
    assert_equal Litestream.socket, "/tmp/my-litestream.sock"
  end
end
