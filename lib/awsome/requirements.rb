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
      @requirements['instances'].collect do |req| 
        instance = req.clone
        instance = inflate(instance, instance.delete('traits'))
        Awsome::InstanceRequirement.new(instance, @options) 
      end
    end

    def filters
      @requirements['filters'] || {}
    end

    def traits
      @requirements['traits'] || {}
    end

    private 

      def find_trait(name)
        raise "no trait called #{name}" unless traits.include?(name)
        traits[name]
      end

      # implements trait inheritance
      def inflate(instance, names)
        inflated = instance.clone

        # prevents loops
        merged = Set[]
        while names && names.any?
          name = names.shift
          if merged.add?(name)
            trait = find_trait(name).clone

            # extract trait supertraits for merging
            names += trait.delete('traits') || []

            inflated = trait.merge(inflated)
          end
        end

        inflated
      end
  end
end

