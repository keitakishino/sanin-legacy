#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'

# Script to enumerate available ports for worktree environments
# Usage: ruby scripts/setup_worktree.rb <worktree_name>
# Output: JSON with {"DB_PORT": number, "APP_PORT": number}

WORKTREES_DIR = '/home/pepo2/worktrees'
DB_PORT_RANGE = (5430..5470).freeze
APP_PORT_RANGE = (3001..3050).freeze
DEFAULT_DB_PORT = 5432
DEFAULT_APP_PORT = 3000

def scan_used_ports
  db_ports = Set.new
  app_ports = Set.new

  Dir.glob("#{WORKTREES_DIR}/*/").each do |worktree_path|
    env_file = File.join(worktree_path, '.env')
    next unless File.exist?(env_file)

    File.readlines(env_file).each do |line|
      line.strip!
      next if line.empty? || line.start_with?('#')

      key, value = line.split('=', 2)
      db_ports << value.to_i if key == 'DB_PORT' && value =~ /^\d+$/
      app_ports << value.to_i if key == 'APP_PORT' && value =~ /^\d+$/
    end
  end

  [ db_ports, app_ports ]
end

def check_existing_worktree(worktree_name)
  # Check if this worktree already has an .env with ports defined
  worktree_path = File.join(WORKTREES_DIR, worktree_name)
  env_file = File.join(worktree_path, '.env')

  return nil unless File.exist?(env_file)

  db_port = nil
  app_port = nil

  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    db_port = value.to_i if key == 'DB_PORT' && value =~ /^\d+$/
    app_port = value.to_i if key == 'APP_PORT' && value =~ /^\d+$/
  end

  [ db_port, app_port ] if db_port && app_port
end

def find_next_available_port(used_ports, range)
  range.each do |port|
    return port unless used_ports.include?(port)
  end

  # If no port available in range, raise error
  raise "No available ports in range #{range.first}-#{range.last}"
end

def main
  worktree_name = ARGV[0]

  if worktree_name.nil? || worktree_name.empty?
    warn "Usage: ruby scripts/setup_worktree.rb <worktree_name>"
    exit 1
  end

  # Check for idempotency: if this worktree already has ports defined, return them
  existing_ports = check_existing_worktree(worktree_name)
  if existing_ports
    db_port, app_port = existing_ports
    puts JSON.generate({ DB_PORT: db_port, APP_PORT: app_port })
    return
  end

  # Scan all used ports across existing worktrees
  db_ports, app_ports = scan_used_ports

  # Add default ports to the "used" set to avoid conflicts
  db_ports << DEFAULT_DB_PORT
  app_ports << DEFAULT_APP_PORT

  # Find next available ports
  new_db_port = find_next_available_port(db_ports, DB_PORT_RANGE)
  new_app_port = find_next_available_port(app_ports, APP_PORT_RANGE)

  # Output as JSON
  puts JSON.generate({ DB_PORT: new_db_port, APP_PORT: new_app_port })
end

main
