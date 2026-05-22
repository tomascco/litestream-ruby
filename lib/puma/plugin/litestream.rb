require "puma/plugin"

# Adapted from https://github.com/rails/solid_queue/blob/main/lib/puma/plugin/solid_queue.rb
Puma::Plugin.create do
  attr_reader :puma_pid, :litestream_pid, :log_writer

  def start(launcher)
    @log_writer = launcher.log_writer
    @puma_pid = $$

    # Puma 7 renamed these lifecycle hooks (on_booted -> after_booted, etc.).
    if Gem::Version.new(Puma::Const::VERSION) < Gem::Version.new("7")
      launcher.events.on_booted { start_litestream }
      launcher.events.on_stopped { stop_litestream }
      launcher.events.on_restart { stop_litestream }
    else
      launcher.events.after_booted { start_litestream }
      launcher.events.after_stopped { stop_litestream }
      launcher.events.before_restart { stop_litestream }
    end
  end

  private

  def start_litestream
    @litestream_pid = fork do
      Thread.new { monitor_puma }
      Litestream::Commands.replicate(async: true)
    end

    in_background do
      monitor_litestream
    end
  end

  def stop_litestream
    Process.waitpid(litestream_pid, Process::WNOHANG)
    log_writer.log "Stopping Litestream..."
    Process.kill(:INT, litestream_pid) if litestream_pid
    Process.wait(litestream_pid)
  rescue Errno::ECHILD, Errno::ESRCH
  end

  def monitor_puma
    monitor(:puma_dead?, "Detected Puma has gone away, stopping Litestream...")
  end

  def monitor_litestream
    monitor(:litestream_dead?, "Detected Litestream has gone away, stopping Puma...")
  end

  def monitor(process_dead, message)
    loop do
      if send(process_dead)
        log message
        Process.kill(:INT, $$)
        break
      end
      sleep 2
    end
  end

  def litestream_dead?
    Process.waitpid(litestream_pid, Process::WNOHANG)
    false
  rescue Errno::ECHILD, Errno::ESRCH
    true
  end

  def puma_dead?
    Process.ppid != puma_pid
  end

  def log(...)
    log_writer.log(...)
  end
end
