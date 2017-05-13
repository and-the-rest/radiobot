#  -*- coding: utf-8 -*-

class Meta
  include Cinch::Plugin

  match /radio/, method: :show_stream
  match /help/, method: :show_help

  def show_stream(m)
    m.reply "#{$STREAM}"
  end

  def show_help(m)
    m.reply "This isn't implemented yet."
  end
end
