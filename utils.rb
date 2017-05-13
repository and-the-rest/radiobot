class Utils
  def self.installed?(cmd)
    ENV["PATH"].split(File::PATH_SEPARATOR).any? do |path|
      File.executable?(File.join(path, cmd))
    end
  end

  def self.running?(cmd)
    Dir["/proc/[0-9]*/comm"].any? do |comm|
      File.read(comm).chomp == cmd rescue false # hooray for TOCTOU
    end
  end
end
