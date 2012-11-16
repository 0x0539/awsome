module Awsome
  module Debian
    def self.describe_debian_packages(hostname)
      if Awsome::Ssh.scp("#{hostname}:/home/ubuntu/packages.csv", './packages.csv')
        File.open('./packages.csv', 'r').read.strip.split(',')
      else
        []
      end
    end

    def self.remove_debian_packages(hostname, *packages)
      installed = describe_debian_packages(hostname)
      remaining = installed.to_set - packages.to_set

      return if packages.empty?

      Awsome::Ssh.ssh hostname, "sudo apt-get update"

      packages.each { |p| Awsome::Ssh.ssh hostname, "sudo apt-get remove -y --force-yes #{p}" }

      Awsome::Ssh.ssh hostname, "echo #{remaining.to_a.join(',')} > ~/packages.csv"
    end

    def self.install_debian_packages(hostname, *packages)
      installed = describe_debian_packages(hostname)
      remaining = installed.to_set + packages.to_set

      Awsome::Ssh.ssh hostname, "sudo apt-get update"

      remaining.each { |p| Awsome::Ssh.ssh hostname, "sudo apt-get install -y --force-yes #{p}" }

      Awsome::Ssh.ssh hostname, "echo #{remaining.to_a.join(',')} > ~/packages.csv"
    end
  end
end
