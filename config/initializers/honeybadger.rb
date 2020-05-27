# frozen_string_literal: true

Honeybadger.configure do |config|
  config.before_notify do |notice|
    # Symphony is unavailable
    notice.halt! if notice.error_message =~ /unableToAcquireSession/
  end
end
