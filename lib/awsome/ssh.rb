module Awsome
  module Ssh
    def self.ensure_ssh_env_vars!
      raise 'SSH_KEY environment variable not set' if ENV['SSH_KEY'].nil?
      raise 'SSH_USER environment varibale not set' if ENV['SSH_USER'].nil?
    end

    def self.ssh(host, *scripts)
      ensure_ssh_env_vars!
      Awsome.execute("ssh -i #{ENV['SSH_KEY']} #{ENV['SSH_USER']}@#{host} \"#{scripts.join(' && ')}\"")
    end

    def self.scp(from, to)
      ensure_ssh_env_vars!
      if File.exists?(from)
        to = "#{ENV['SSH_USER']}@#{to}" 
      else
        from = "#{ENV['SSH_USER']}@#{from}"
      end
      Awsome.execute("scp -i #{ENV['SSH_KEY']} #{from} #{to}", system: true, output: false)
    end

    def self.has_ssh?(host)
      Awsome.execute("nc -zw 2 #{host} 22 < /dev/null", system: true, verbose: false)
    end
  end
end
