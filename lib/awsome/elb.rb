module Awsome
  module Elb
    @@delimiter = " OH YEAH BANANAS "

    def self.config
      Awsome.config
    end

    def self.command(*cmd)
      args = cmd.last.is_a?(Hash) && cmd.pop
      options = cmd
      options << "--region #{config.region}"
      # options << "--url #{config.url}" # explicitly setting the url this way breaks the elb tools
      options << "--access-key-id #{config.aws_access_key}"
      options << "--secret-key #{config.aws_secret_key}"
      options << "--show-long"
      options << "--delimiter \"#{@@delimiter}\""
      options << "--show-request" if config.show_request
      options << "--show-empty-fields" if config.show_empty_fields
      options << "--connection-timeout #{config.connection_timeout}" if config.connection_timeout
      args && args.each { |k,v| options << "--#{k} #{v}" }
      options.join(' ')
    end

    @@describe_lbs_columns = %w(
      identifier
      name
      dns_name
      canonical_hosted_zone_name
      canonical_hosted_zone_name_id
      health_check
      availability_zones
      subnets
      vpc_id
      instance_ids
      listener_descriptions
      backend_server_descriptions
      app_cookie_stickiness_policies
      lb_cookie_stickiness_policies
      other_policies
      source_security_group
      security_groups
      created_time
      scheme
      pagination_marker
    )

    def self.describe_lbs(*load_balancer_names)
      cmd = Awsome::Elb.command("elb-describe-lbs #{load_balancer_names.join(' ')}")
      properties = Awsome.execute(cmd, columns: @@describe_lbs_columns, delimiter: @@delimiter)
      properties.collect { |p| Awsome::Elb::LoadBalancer.new(p) }
    end

    def self.deregister_instance_from_lb(load_balancer_name, instance_id)
      cmd = Awsome::Elb.command('elb-deregister-instances-from-lb', load_balancer_name, instances: instance_id, delimiter: @@delimiter)
      Awsome.execute(cmd)
    end

    def self.register_instance_with_lb(load_balancer_name, instance_id)
      cmd = Awsome::Elb.command('elb-register-instances-with-lb', load_balancer_name, instances: instance_id, delimiter: @@delimiter)
      Awsome.execute(cmd)
    end
  end
end

require 'awsome/elb/load_balancer.rb'
