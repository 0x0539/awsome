require 'yaml'

module Awsome
  class Requirements
    attr_reader :options
    def initialize(requirements_hash)
      @requirements = requirements_hash.clone
      @options = Awsome::RequirementsOptions.new(@requirements)
    end
    def self.from_yaml_file(filename)
      new(YAML::load(File.open(filename, 'r').read))
    end
    def instances
      @requirements['instances'].collect do |instance_req| 
        Awsome::InstanceRequirement.new(instance_req, @options) 
      end
    end
  end
end

