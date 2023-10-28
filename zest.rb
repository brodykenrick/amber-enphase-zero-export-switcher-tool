#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH << File.expand_path('lib', __dir__)

require 'bundler/setup'

require 'dotenv/load'
require 'green_log'

require 'zest/amber/client'
require 'zest/enphase/client'
require 'zest/enphase/manager'

logger = GreenLog::Logger.build(severity_threshold: ENV.fetch('ZEST_LOG_LEVEL'))

STDOUT.sync = true

amber_client = Zest::Amber::Client.new(
  logger:,
  site_id: ENV.fetch('ZEST_AMBER_SITE_ID'),
  token: ENV.fetch('ZEST_AMBER_TOKEN'),
)

enphase_client = Zest::Enphase::Client.new(
  logger:,
  envoy_ip: ENV.fetch('ZEST_ENPHASE_ENVOY_IP'),
  envoy_serial_number: ENV.fetch('ZEST_ENPHASE_ENVOY_SERIAL_NUMBER'),
  envoy_installer_username: ENV.fetch('ZEST_ENPHASE_ENVOY_INSTALLER_USERNAME'),
  envoy_installer_password: ENV.fetch('ZEST_ENPHASE_ENVOY_INSTALLER_PASSWORD'),
)

enphase_manager = Zest::Enphase::Manager.new(
  logger:,
  enphase_client:,
  envoy_grid_profile_name_normal_export: ENV.fetch('ZEST_ENPHASE_ENVOY_GRID_PROFILE_NAME_NORMAL_EXPORT'),
  envoy_grid_profile_name_zero_export: ENV.fetch('ZEST_ENPHASE_ENVOY_GRID_PROFILE_NAME_ZERO_EXPORT'),
  status_file_path: ENV.fetch('ZEST_STATUS_FILE', nil),
  post_switch_custom_command: ENV.fetch('ZEST_COMMAND_TO_RUN_AFTER_SWITCHING_GRID_PROFILE', nil),
)

amber_poll_interval_seconds = Float(ENV.fetch('ZEST_AMBER_POLL_INTERVAL_SECONDS'))

loop do
  begin
    if amber_client.costs_me_to_export?
      enphase_manager.set_export_limit_to_zero
    else
      enphase_manager.set_export_limit_to_normal
    end
  rescue => e
    puts "Error: #{e}", e.backtrace
    puts "Refreshing token - assuming it is a 401 token issue (so a refresh will recover)"
    enphase_client.get_refreshed_token
  end
  puts
  sleep amber_poll_interval_seconds
end
