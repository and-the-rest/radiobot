# frozen_string_literal: true

require "ruby-mpd"
require "open3"
require "json"

class Radio
  include Cinch::Plugin

  match /queue (.+)/, method: :queue

  def queue(m, query)
    hsh, url = youtube_search(query)
    m.reply "enqueueing: #{hsh["title"]}"
    mpd.add url
    mpd.play unless mpd.playing?
  rescue => e
    m.reply "something exploded: #{e}"
  end

  def mpd
    @mpd ||= MPD.new
    @mpd.connect unless @mpd.connected?
    @mpd
  rescue => e
    raise "error during MPD connection: #{e}"
  end

  def youtube_search(query)
    query = "ytsearch1:#{query}"
    args = ["youtube-dl", "--prefer-insecure", "-j", query]

    hsh = begin
      Open3.popen2(*args) do |stdin, stdout, _|
        stdin.close
        JSON.parse(stdout.read)
      end
    rescue => e
      raise "error during youtube query: #{e}"
    end

    # get all the audio-only + http formats first
    audio_fmts = hsh["formats"].select do |fmt|
      fmt["vcodec"] == "none" && fmt["url"] =~ %r{^http://}
    end

    # select the highest bitrate
    audio_fmt = audio_fmts.max_by { |fmt| fmt["abr"] }

    [hsh, audio_fmt["url"]]
  rescue => e
    raise "error during audio discovery: #{e}"
  end
end
