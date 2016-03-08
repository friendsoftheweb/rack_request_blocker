require "rack_request_blocker/version"
require 'concurrent'

# Rack middleware that keeps track of the number of active requests and can block new requests.
# http://blog.salsify.com/engineering/tearing-capybara-ajax-tests
class RackRequestBlocker
  @@num_active_requests = Concurrent::AtomicFixnum.new(0)
  @@allowing_requests = Concurrent::Event.new.tap { |e| e.set }

  # Returns the number of requests the server is currently processing.
  def self.num_active_requests
    @@num_active_requests.value
  end

  # Prevents the server from accepting new requests. Any new requests will return an HTTP
  # 503 status.
  def self.block_requests!
    @@allowing_requests.reset
  end

  # Allows the server to accept requests again.
  def self.allow_requests!
    @@allowing_requests.set
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    increment_active_requests
    if block_requests?
      block_request(env)
    else
      @app.call(env)
    end
  ensure
    decrement_active_requests
  end



  def self.wait_for_no_active_requests(max_wait_time: 10, for_example: nil, diagnostic_log: true)
    RackRequestBlocker.block_requests!

    unless num_active_requests == 0 || diagnostic_log == false
      msg = "Waiting on #{num_active_requests} active requests"
      msg += " for #{for_example.location}" if for_example
      log msg
    end

    obtained = (num_active_requests == 0) || @@allowing_requests.wait(max_wait_time)
    unless obtained
      raise Timeout::Error, "rack_request_blocker gave up waiting #{max_wait_time}s for pending AJAX requests complete"
    end
  ensure
    RackRequestBlocker.allow_requests!
  end

  private

  def self.log(msg)
    $stderr.puts "\nrack_request_blocker: #{msg}"
  end

  def block_requests?
    ! @@allowing_requests.set?
  end

  def block_request(env)
    [503, {}, ['Blocked by rack_request_blocker, requests blocked while waiting for in-progress requests to complete']]
  end

  def increment_active_requests
    @@num_active_requests.increment
  end

  def decrement_active_requests
    new_value = @@num_active_requests.decrement
    if new_value == 0
      RackRequestBlocker.allow_requests!
    end
  end
end