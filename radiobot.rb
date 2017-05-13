#  -*- coding: utf-8 -*-
require "cinch"

require_relative "controls"
require_relative "meta"
require_relative "admin"

$NAME = "nately"
$MUSIC = File.expand_path("~/radio/music")
$STREAM = "https://thing-in-itself.net/radio"

Cinch::Bot.new do
  configure do |c|
    c.nick = c.realname = c.user = $NAME
    c.server = "irc.rizon.net"
    c.port = 6697
    c.ssl.use = true
    c.channels = ["#etc"]
    c.plugins.prefix = /^#{$NAME}: /
    # c.plugins.plugins = [Controls, Meta, Admin]
    c.plugins.plugins = [Controls, Meta]
  end
end.start
