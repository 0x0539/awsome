module Awsome
  def self.config
    @@config ||= Config.new
  end

  def self.execute(command, options={})
    command = command.join(' ') if command.is_a?(Array)
    if config.verbose
      puts
      puts command
      puts '='*command.length
    end
    if options[:system]
      result = system(command)
    else
      result = `#{command}`
      result = options[:preprocess].call(result) if options[:preprocess]
      result = map_table(result, options)
    end
  ensure
    if config.verbose
      case result
      when String then puts result
      else ap result
      end
    end
    if config.stacks
      ap Kernel.caller
    end
  end

  def self.map_table(table, options)
    return table unless options[:columns]
    rows = table.split("\n")
    rows.select! { |row| row =~ options[:filter] } if options[:filter]
    rows.collect do |row|
      properties = {}
      values = options[:delimiter] ? row.split(options[:delimiter]) : row.split
      values.each_with_index { |value, index| 
        field = options[:columns][index]
        properties[field] = value
      }
      properties
    end
  end

  def self.wait_until(opts={}, &block)
    retries = opts[:retries] || 5
    interval = opts[:interval] || 5
    while !yield && retries > 0
      puts "block returned false (#{retries} more retries)..." if Awsome.config.verbose
      sleep interval
      retries -= 1
    end
  end

  class Config
    attr_accessor :region, :url, :aws_access_key, :aws_secret_key, :connection_timeout, 
      :request_timeout, :verbose, :show_empty_fields, :debug, :show_request, :stacks

    def initialize
      @region = ENV['REGION']
      @url = ENV['EC2_URL']
      @aws_access_key = ENV['AWS_ACCESS_KEY']
      @aws_secret_key = ENV['AWS_SECRET_KEY']
      @show_empty_fields = true
    end
  end
end

require 'set'
require 'awesome_print'
require 'awsome/ec2.rb'
require 'awsome/elb.rb'
require 'awsome/ssh.rb'
require 'awsome/r53.rb'
require 'awsome/debian.rb'
require 'awsome/requirements.rb'
require 'awsome/executor.rb'
require 'awsome/matchmaker.rb'
require 'awsome/requirements_options.rb'
require 'awsome/instance_requirement.rb'
