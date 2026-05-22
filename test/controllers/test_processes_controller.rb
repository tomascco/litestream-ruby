require "test_helper"

class Litestream::TestProcessesController < ActionDispatch::IntegrationTest
  test "should show the process" do
    stubbed_process = {pid: "12345", status: "sleeping", started: DateTime.now}
    stubbed_databases = [
      {"path" => "[ROOT]/storage/test.sqlite3",
       "status" => "active",
       "last_sync_at" => "2026-02-25T10:00:00Z",
       "ltx" => [
         {"min_txid" => "0000000000000001", "max_txid" => "0000000000000010", "size" => 4096,
          "created" => "2026-02-25T10:00:00Z", "level" => "0"}
       ]}
    ]
    Litestream.stub :replicate_process, stubbed_process do
      Litestream.stub :databases, stubbed_databases do
        get litestream.process_url
        assert_response :success

        assert_select "#process_12345", 1 do
          assert_select "small", "sleeping"
          assert_select "code", "12345"
          assert_select "time", stubbed_process[:started].to_formatted_s(:db)
        end

        assert_select "#databases li", 1 do
          assert_select "h2 code", stubbed_databases[0]["path"]
        end
      end
    end
  end
end
