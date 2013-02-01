require 'terminal-table'

module Awsome
  module Ec2
    class Instance
      attr_reader :properties

      def initialize(property_hash)
        raise 'properties must be a hash' unless property_hash.is_a?(Hash)
        @properties = property_hash.clone
      end

      def packages(options={})
        return @cached_packages if @cached_packages && options[:cached_ok]
        @cached_packages = Awsome::Debian.describe_debian_packages(@properties['public_dns_name']).to_set
      end

      def volumes(options={})
        return @cached_volumes if @cached_volumes && options[:cached_ok]
        @cached_volumes = Awsome::Ec2.describe_attachments(
          'attachment.instance-id' => @properties['instance_id']
        ).collect{ |p| p['volume_id'] }.to_set
      end

      def wait_until_running!
        Awsome.wait_until(interval: 20) do
          reload! 
          @properties['state'] =~ /^running/
        end
      end

      def wait_for_ssh!
        Awsome.wait_until(interval: 20) { has_ssh? }
      end

      def ssh(*args)
        Awsome::Ssh.ssh(@properties['public_dns_name'], *args)
      end

      def associate_cnames(*cnames)
        cnames.each do |cname| 
          zone = cname['zone']
          (cname['private'] || []).each do |name| 
            Awsome::R53.redefine_cname(zone, name, @properties['private_dns_name'])
          end
          (cname['public'] || []).each do |name| 
            Awsome::R53.redefine_cname(zone, name, @properties['public_dns_name'])
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

      def detach_volumes(*volumes)
        volumes.each do |info|
          Awsome::Ec2.detach_volume(info['id'], info['dir'], info['preumount'])
        end
      end

      def deregister_from_elbs
        elbs.each { |elb| elb.deregister(@properties['instance_id']) }
      end

      def register_with_elbs(*load_balancer_names)
        return if load_balancer_names.empty?
        Awsome::Elb.describe_lbs(*load_balancer_names).each { |elb| elb.register(@properties['instance_id']) }
      end

      def remove_packages(*packages)
        Awsome::Debian.remove_debian_packages(@properties['public_dns_name'], *packages)
      end

      def install_packages(*packages)
        Awsome::Debian.install_debian_packages(@properties['public_dns_name'], *packages)
      end

      def autoremove_packages
        Awsome::Debian.autoremove_debian_packages(@properties['public_dns_name'])
      end

      def terminate
        Awsome::Ec2.terminate_instances(@properties['instance_id'])
      end

      def create_tags(tags)
        Awsome::Ec2.create_tags(@properties['instance_id'], tags)
      end

      def self.to_table(instances, title='Instances')
        rows = []

        # add instance rows
        instances.each do |instance|
          rows << [
            instance.id,
            instance.public_dns_name,
            instance.packages.to_a.join("\n"),
            instance.volumes.to_a.join("\n"),
            instance.elbs.collect(&:name).join("\n"),
            instance.ami_id,
            instance.key,
            instance.instance_type,
            instance.availability_zone,
            instance.security_group_ids
          ]
          rows << :separator
        end

        # remove last unnecessary separator
        rows.pop if rows.any?

        headings = %w(id dns packages volumes elbs ami key type zone secgroup)
        Terminal::Table.new :headings => headings, :rows => rows, :title => title
      end

      def elbs
        Awsome::Elb.describe_lbs.select { |elb| elb.instances.include?(@properties['instance_id']) }
      end

      def id
        @properties['instance_id']
      end

      def public_dns_name
        @properties['public_dns_name']
      end

      def ami_id
        @properties['ami_id']
      end

      def key
        @properties['key']
      end

      def instance_type
        @properties['instance_type']
      end

      def availability_zone
        @properties['availability_zone']
      end

      def security_group_ids
        @properties['security_group_ids']
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

    end
  end
end
