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
        reattach_volumes
        deploy
        terminate
      end

      def run
        @i_pool.each_with_index do |instance, i|
          @i_pool[i] = Awsome::Ec2.run_instance(@r_pool[i].properties) if instance.nil?
        end
      end

      def wait_for_ssh
        @i_pool.each do |i|
          i.wait_until_running!
          i.wait_for_ssh!
        end
      end

      def reattach_volumes
        @i_pool.each_with_index do |instance, i|
          instance.reattach_volumes(*@r_pool[i].volumes_to_attach(instance))
        end
      end

      def deploy
        @i_pool.each_with_index do |instance, i|
          instance.deregister_from_elbs
          instance.remove_packages(*@r_pool[i].packages_to_remove(instance))
          instance.install_packages(*@r_pool[i].packages_to_install(instance))
          instance.register_with_elbs(*@r_pool[i].elbs)
        end
      end

      def terminate
        @i_pool.each_with_index do |instance, i|
          next if i < @r_pool.length
          instance.deregister_from_elbs
          instance.terminate
        end
      end
    end
end
