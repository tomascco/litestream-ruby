# frozen_string_literal: true

require "sqlite3"
require "yaml"

module Litestream
  VerificationFailure = Class.new(StandardError)

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("0.12.0", "Litestream")
    end
  end

  def self.configure
    deprecator.warn(
      "Configuring Litestream via Litestream.configure is deprecated. Use Rails.application.configure { config.litestream.* = ... } instead.",
      caller
    )
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :replica_bucket, :replica_key_id, :replica_access_key
  end

  mattr_writer :username, :password, :queue, :replica_bucket, :replica_region, :replica_endpoint, :replica_key_id,
    :replica_access_key, :systemctl_command, :config_path, :socket
  mattr_accessor :base_controller_class, default: "::ApplicationController"

  class << self
    def verify!(database_path, replication_sleep: 10)
      database = SQLite3::Database.new(database_path)
      database.execute("CREATE TABLE IF NOT EXISTS _litestream_verification (id INTEGER PRIMARY KEY, uuid BLOB)")
      sentinel = SecureRandom.uuid
      database.execute("INSERT INTO _litestream_verification (uuid) VALUES (?)", [sentinel])
      # give the Litestream replication process time to replicate the sentinel value
      sleep replication_sleep

      backup_path = "tmp/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_#{sentinel}.sqlite3"
      Litestream::Commands.restore(database_path, **{"-o" => backup_path})

      backup = SQLite3::Database.new(backup_path)
      result = backup.execute("SELECT 1 FROM _litestream_verification WHERE uuid = ? LIMIT 1", sentinel) # => [[1]] || []

      raise VerificationFailure, "Verification failed for `#{database_path}`" if result.empty?

      true
    ensure
      database.execute("DELETE FROM _litestream_verification WHERE uuid = ?", sentinel)
      database.close
      Dir.glob(backup_path + "*").each { |file| File.delete(file) }
    end

    # use method instead of attr_accessor to ensure
    # this works if variable set after Litestream is loaded
    def username
      ENV["LITESTREAM_USERNAME"] || @@username || "litestream"
    end

    def password
      ENV["LITESTREAM_PASSWORD"] || @@password
    end

    def queue
      ENV["LITESTREAM_QUEUE"] || @@queue || "default"
    end

    def replica_bucket
      @@replica_bucket || configuration.replica_bucket
    end

    def replica_region
      @@replica_region
    end

    def replica_endpoint
      @@replica_endpoint
    end

    def replica_key_id
      @@replica_key_id || configuration.replica_key_id
    end

    def replica_access_key
      @@replica_access_key || configuration.replica_access_key
    end

    def systemctl_command
      @@systemctl_command || "systemctl status litestream"
    end

    def config_path
      @@config_path || Rails.root.join("config", "litestream.yml")
    end

    def socket
      @@socket || read_socket_from_config
    end

    def read_socket_from_config
      default = "/var/run/litestream.sock"

      unless File.exist?(config_path)
        warn "[Litestream] Config file not found: #{config_path}, using default: #{default}"
        return default
      end

      config = YAML.safe_load_file(config_path)
      unless config
        warn "[Litestream] Config file is empty, using default: #{default}"
        return default
      end

      socket_path = config.dig("socket", "path")
      result = socket_path || default

      result
    rescue Errno::ENOENT, Psych::SyntaxError => e
      warn "[Litestream] Warning: Could not read socket path from config: #{e.message}"
      "/var/run/litestream.sock"
    end

    def replicate_process
      info = IPC.info(socket)
      {
        pid: info["pid"],
        status: "running",
        started: DateTime.parse(info["started_at"])
      }
    end

    def databases
      list = IPC.list(socket)
      list["databases"].map do |db|
        db.merge("ltx" => Commands.ltx(db["path"], "-level" => "all"))
      end
    end
  end
end

require_relative "litestream/version"
require_relative "litestream/ipc"
require_relative "litestream/upstream"
require_relative "litestream/commands"
require_relative "litestream/engine" if defined?(::Rails::Engine)
