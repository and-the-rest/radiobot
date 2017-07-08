#!/usr/bin/env ruby
# frozen_string_literal: true

require "cinch"

require_relative "radio"

Cinch::Bot.new do
  configure do |c|
    c.nick = c.realname = c.user = "nately"
    c.server = "irc.rizon.net"
    c.port = 6697
    c.ssl.use = true
    c.channels = ["#etc"]
    c.plugins.prefix = /^#{c.nick}: /
    c.plugins.plugins = [Radio]
  end
end.start
