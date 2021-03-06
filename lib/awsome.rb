require 'terminal-table'

module Awsome
  def self.config
    @@config ||= Config.new
  end

  def self.execute(command, options={})
    command = command.join(' ') if command.is_a?(Array)
    description = options[:task] ? "[#{options[:task].upcase}] #{command}" : command
    verbose = config.verbose && options[:verbose] != false
    if verbose
      puts
      puts description
    end
    if options[:system]
      result = system(command)
    else
      result = `#{command}`
      result = options[:preprocess].call(result) if options[:preprocess]
      result = map_table(result, options)
    end
  ensure
    if verbose && options[:output] != false
      puts '-' * description.length
      if result.is_a?(Array)
        if result.any?
          headings = result.first.collect(&:first)
          rows = result.collect{|r| headings.collect{|h| r[h]}}
          puts Terminal::Table.new headings: headings, rows: rows
        else
          puts Terminal::Table.new title: 'No Results'
        end
      else
        puts result
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
      if config.verbose
        task = opts[:task] || 'block returned false'
        puts "[#{retries} more retries] #{task}"
      end
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
