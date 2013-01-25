module Awsome
  module Ec2
    def self.config
      Awsome.config
    end

    def self.command(*cmd)
      args = cmd.last.is_a?(Hash) && cmd.pop
      options = cmd
      options << "--region #{config.region}"
      options << "--url #{config.url}"
      options << "--aws-access-key #{config.aws_access_key}"
      options << "--aws-secret-key #{config.aws_secret_key}"
      options << "--connection-timeout #{config.connection_timeout}" if config.connection_timeout
      options << "--request-timeout #{config.request_timeout}" if config.request_timeout
      options << "--verbose" if config.verbose
      options << "--show-empty-fields" if config.show_empty_fields
      options << "--debug" if config.debug
      args && args.each { |k,v| options << "--#{k} #{v}" }
      options.join(' ')
    end

    def self.map_table(*args)
      Awsome.map_table(*args)
    end

    @@run_instance_fields = %w(
      instance_identifier
      instance_id
      ami_id
      state
      key
      ami_launch_index
      product_code
      instance_type
      instance_launch_time
      availability_zone
    )

    def self.run_instance(properties)
      cmd = command('ec2-run-instances', properties['ami_id'], 
        :group => properties['security_group_ids'], 
        :key => properties['key'], 
        'instance-type'.to_sym => properties['instance_type'], 
        'availability-zone'.to_sym => properties['availability_zone']
      )
      Awsome::Ec2::Instance.new(Awsome.execute(cmd, columns: @@run_instance_fields, filter: /^INSTANCE/).first)
    end

    def self.create_tags(resource_id, tags)
      tags = tags.collect { |k, v| v ? "--tag #{k}=#{v}" : "--tag #{k}" }
      cmd = command('ec2-create-tags', resource_id, *tags)
      Awsome.execute(cmd)
    end

    @@describe_instance_fields = %w( 
      reservation_identifier
      reservation_id
      aws_account_id
      security_group_ids
      instance_identifier
      instance_id
      ami_id
      public_dns_name
      private_dns_name
      state
      key
      ami_launch_index
      product_codes
      instance_type
      instance_launch_time
      availability_zone
    )

    def self.describe_instances(filters={})
      cmd = [Awsome::Ec2.command('ec2-describe-instances')]
      cmd += filters.collect { |k,v| "--filter \"#{k}=#{v}\"" }
      preprocess = Proc.new { |text| text.gsub("\nINSTANCE", " INSTANCE") }
      properties = Awsome.execute(cmd, columns: @@describe_instance_fields, filter: /^RESERVATION/, preprocess: preprocess)
      properties.collect { |p| Awsome::Ec2::Instance.new(p) }
    end

    @@describe_volumes_fields = %w(
      volume_identifier
      volume_id
      size_gb
      iops
      availability_zone
      state
      timestamp
      type
    )

    def self.describe_volumes(*volume_ids)
      cmd = [Awsome::Ec2.command('ec2-describe-volumes')] + volume_ids
      Awsome.execute(cmd, columns: @@describe_volumes_fields, filter: /^VOLUME/)
    end

    def self.volume_available?(volume_id)
      volumes = describe_volumes(volume_id)
      raise "volume #{volume_id} not found" if volumes.empty?
      volumes.first['state'] == 'available'
    end

    @@describe_attachments_fields = %w(
      attachment_identifier
      volume_id
      instance_id
      device
      state
      date
    )

    def self.describe_attachments(filters={})
      cmd = [Awsome::Ec2.command('ec2-describe-volumes')]
      cmd += filters.collect { |k,v| "--filter \"#{k}=#{v}\"" }
      Awsome.execute(cmd, columns: @@describe_attachments_fields, filter: /^ATTACHMENT/)
    end

    def self.detach_volume(volume_id, dir, preumount)
      attachments = describe_attachments('volume-id' => volume_id)
      if attachments.any?
        instance_id = attachments.first['instance_id']
        instance = describe_instances('instance-id' => instance_id).first
        instance.ssh preumount if preumount
        instance.ssh "sudo umount #{dir}"

        cmd = Awsome::Ec2.command('ec2-detach-volume', volume_id)
        Awsome.execute(cmd)
      end
    end

    @@associate_address_columns = %w(
      identifier 
      elastic_ip
      instance_id
    )

    def self.associate_address(instance_id, ip_address)
      cmd = Awsome::Ec2.command('ec2-associate-address', ip_address, instance: instance_id)
      Awsome.execute(cmd, columns: @@associate_address_columns, filter: /^ADDRESS/)
    end

    def self.attach_volume(volume_id, instance_id, device)
      cmd = Awsome::Ec2.command('ec2-attach-volume', volume_id, instance: instance_id, device: device)
      Awsome.execute(cmd)
    end

    def self.terminate_instances(*instance_ids)
      cmd = Awsome::Ec2.command("ec2-terminate-instances #{instance_ids.join(' ')}") 
      Awsome.execute(cmd)
    end
  end
end

require 'awsome/ec2/instance.rb'
