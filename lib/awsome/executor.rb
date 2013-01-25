module Awsome
  class Executor
    def initialize(matches)
      @matches = matches
    end

    def execute
      @matches.each { |s, m| execute_match(s, m) }
    end

    private

      def execute_match(signature, match)
        @i_pool = match[:i_pool]
        @r_pool = match[:r_pool]

        run
        wait_for_ssh
        tag_instances
        reattach_volumes
        deploy
        terminate
      end

      def instances_to_use(&block)
        @i_pool.each_with_index do |instance, index|
          yield(instance, @r_pool[index]) if index < @r_pool.length
        end
      end

      def instances_to_terminate(&block)
        @i_pool.each_with_index do |instance, index|
          yield(instance) if index >= @r_pool.length
        end
      end

      def run
        @i_pool.each_with_index do |instance, i|
          @i_pool[i] = Awsome::Ec2.run_instance(@r_pool[i].properties) if instance.nil?
        end
      end

      def wait_for_ssh
        instances_to_use do |instance, requirement|
          instance.wait_until_running!
          instance.wait_for_ssh!
        end
      end

      def tag_instances
        instances_to_use do |instance, requirement|
          instance.create_tags(requirement.tags)
        end
      end

      def reattach_volumes
        instances_to_use do |instance, requirement|
          instance.reattach_volumes(*requirement.volumes_to_attach(instance))
        end
      end

      def deploy
        instances_to_use do |instance, requirement|
          instance.deregister_from_elbs
          instance.remove_packages(*requirement.packages_to_remove(instance))
          instance.install_packages(*requirement.packages_to_install(instance))
          instance.associate_cnames(*requirement.cnames)
          instance.associate_ips(*requirement.elastic_ips)
          instance.register_with_elbs(*requirement.elbs)
        end
      end

      def terminate
        instances_to_terminate do |instance|
          instance.deregister_from_elbs
          instance.terminate
        end
      end
    end
end
