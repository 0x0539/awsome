module Awsome
  module Ec2
    class Instance
      attr_reader :properties

      def initialize(property_hash)
        raise 'properties must be a hash' unless property_hash.is_a?(Hash)
        @properties = property_hash.clone
      end

      def packages
        Awsome::Debian.describe_debian_packages(@properties['public_dns_name']).to_set
      end

      def volumes
        Awsome::Ec2.describe_attachments('attachment.instance-id' => @properties['instance_id']).collect do |p| 
          p['volume_id'] 
        end.to_set
      end

      def wait_until_running!
        Awsome.wait_until(interval: 10) do
          reload! 
          @properties['state'] =~ /^running/
        end
      end

      def wait_for_ssh!
        Awsome.wait_until(interval: 10) { has_ssh? }
      end

      def ssh(*args)
        Awsome::Ssh.ssh(@properties['public_dns_name'], *args)
      end

      def associate_cnames(*cnames)
        cnames.each do |cname| 
          zone = cname['zone']
          cname['names'].each do |name| 
            Awsome::R53.redefine_cname(zone, name, @properties['private_dns_name'])
          end
        end
      end

      def associate_ips(*elastic_ips)
        elastic_ips.each do |ip|
          Awsome::Ec2.associate_address(@properties['instance_id'], ip)
        end
      end

      def reattach_volumes(*volumes)
        volumes.each do |info| 
          Awsome::Ec2.detach_volume(info['id'], info['dir'], info['preumount'])
          Awsome.wait_until(interval: 10) { Awsome::Ec2.volume_available?(info['id']) }
          Awsome::Ec2.attach_volume(info['id'], @properties['instance_id'], info['device']) 
        end
      end

      def deregister_from_elbs
        elbs.each { |elb| elb.deregister(@properties['instance_id']) }
      end

      def register_with_elbs(*load_balancer_names)
        Awsome::Elb.describe_lbs(*load_balancer_names).each { |elb| elb.register(@properties['instance_id']) }
      end

      def remove_packages(*packages)
        Awsome::Debian.remove_debian_packages(@properties['public_dns_name'], *packages)
      end

      def install_packages(*packages)
        Awsome::Debian.install_debian_packages(@properties['public_dns_name'], *packages)
      end

      def terminate
        Awsome::Ec2.terminate_instances(@properties['instance_id'])
      end

      private 
        def reload!
          instance = Awsome::Ec2.describe_instances('instance-id' => @properties['instance_id']).first
          raise "instance #{@properties['instance_id']} not found" if instance.nil?
          @properties = instance.properties.clone
        end

        def has_ssh?
          Awsome::Ssh.has_ssh?(@properties['public_dns_name'])
        end

        def elbs
          Awsome::Elb.describe_lbs.select { |elb| elb.instances.include?(@properties['instance_id']) }
        end

    end
  end
end
