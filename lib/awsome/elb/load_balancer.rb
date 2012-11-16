module Awsome
  module Elb
    class LoadBalancer
      attr_reader :properties
      
      def initialize(property_hash)
        @properties = property_hash.clone
      end

      def instances
        @properties['instance_ids'].gsub('"', '').split(',').collect(&:strip).to_set
      end

      def deregister(instance_id)
        Awsome::Elb.deregister_instance_from_lb(@properties['name'], instance_id)
      end

      def register(instance_id)
        Awsome::Elb.register_instance_with_lb(@properties['name'], instance_id)
      end

      private
        def reload!
          elb = Awsome::Elb.describe_lbs(@properties['name']).first
          raise "elb #{@properties['name']} not found" if elb.nil?
          @properties = elb.properties.clone
        end
    end
  end
end
