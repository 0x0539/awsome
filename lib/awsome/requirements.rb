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

            inflated = recursive_merge(trait, inflated)
          end
        end

        p inflated

        inflated
      end

      def recursive_merge(base, overrides)
        base.merge(overrides) do |key, lval, rval|
          case
          when lval.is_a?(Hash ) && rval.is_a?(Hash ) then recursive_merge(lval, rval)
          when lval.is_a?(Array) && rval.is_a?(Array) then lval + rval
          else rval || lval
          end
        end
      end
  end
end

