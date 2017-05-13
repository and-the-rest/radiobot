#  -*- coding: utf-8 -*-
require "ruby-mpd"
require "uri"
require "http"
require "open3"

require_relative "utils"

class Controls
  include Cinch::Plugin

  YOUTUBE_DOMAINS = [
    "youtube.com",
    "www.youtube.com",
    "youtu.be",
    "www.youtu.be",
  ]

  SOUNDCLOUD_DOMAINS = [
    "soundcloud.com",
  ]

  BANDCAMP_DOMAINS = [
    "bandcamp.com"
  ]

  DOMAIN_WHITELIST = YOUTUBE_DOMAINS + SOUNDCLOUD_DOMAINS + BANDCAMP_DOMAINS

  URI_REGEXP = URI.regexp(["http", "https"])

  match /(#{URI_REGEXP})/, use_prefix: false, method: :mark_last
  match /add (last|#{URI_REGEXP})/, method: :add
  match /list/, method: :list

  def mark_last(m, url)
    @last = url
  end

  def add(m, thing)
    if thing == "last" && @last
      if @last
        thing = @last
      else
        m.reply "No last thing to add!"
        return
      end
    end

    url = URI(thing)

    unless safe_domain?(url)
      m.reply "Whoops: '#{url.host}' isn't on my whitelist. Bug an admin."
      return
    end

    case url.host
    when *YOUTUBE_DOMAINS
      path = sanitize_and_fetch_youtube url
      if path.nil?
        m.reply "I couldn't fetch that URL."
      else
        m.reply "Queued: #{path}"
        mpd.update
        begin
          sleep 2 # this is more than enough time, right?
          mpd.add(mpd_escape path)
        rescue # lmao
          retry
        end
      end
    else
      m.reply "I can't stream those URLs yet. Maybe soon."
    end
  end

  def list(m)
    active_queue = mpd.queue[mpd.status[:nextsong]..-1]
    active_queue.take(3).each do |song|
      m.reply "#{song.file}"
    end
  end

  private

  def mpd_escape(str)
    str.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
  end

  def safe_domain?(url)
    DOMAIN_WHITELIST.include?(url.host)
  end

  def expand_youtube_url(url)
    case url.host
    when "www.youtu.be", "youtu.be"
      id = url.path[1..-1]
      URI("https://youtube.com/watch?v=#{id}")
    else
      url
    end
  end

  def sanitize_and_fetch_youtube(url)
    # convert youtu.be slugs into youtube.com urls
    url = expand_youtube_url(url)

    query = URI.decode_www_form(url.query).to_h

    # delete every parameter except the video id, since we don't want
    # youtube-dl making long playlist queries
    query.delete_if { |k, _| k != "v" }

    # if the v param is nonexistent or blank, there's not much we can do
    return if query["v"].nil? || query["v"].empty?

    clean_url = URI(url)
    clean_url.query = URI.encode_www_form(query)

    cmdline = [
      "youtube-dl",
      "-j",
      clean_url.to_s,
    ]

    begin
      blob = Open3.popen2(*cmdline) do |stdin, stdout, _|
        stdin.close
        JSON.parse(stdout.read)
      end
    rescue
      return
    end

    # filter down to audio-only first
    all_audio_fmts = blob["formats"].select { |fmt| fmt["vcodec"] == "none" }

    # prioritize vorbis
    audio_fmts = all_audio_fmts.select { |fmt| fmt["acodec"] == "vorbis" }
    audio_fmts = all_audio_fmts.select { |fmt| fmt["acodec"] =~ /^mp4a/ } if audio_fmts.empty?

    # choose the highest bitrate
    audio_fmt = audio_fmts.max_by { |fmt| fmt["abr"] }

    audio = HTTP.get(audio_fmt["url"]).to_s
    fname = "#{blob["title"]}.#{audio_fmt["ext"]}"
    path = File.join($MUSIC, fname)
    File.write(path, audio)

    # mpd doesn't expect the absolute path
    fname
  end

  def mpd
    @mpd ||= MPD.new
    @mpd.connect unless @mpd.connected?
    @mpd
  end
end
