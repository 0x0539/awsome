module Awsome
  class InstanceRequirement

    attr_reader :properties

    def initialize(properties, options)
      @properties = properties.clone
      @options = options
    end

    def elbs
      @properties['elbs'] || []
    end

    def elastic_ips
      @properties['elastic_ips'] || []
    end

    def volumes_to_attach(instance)
      (volumes - volumes_attached_to(instance)).collect { |v| @options.find_volume(v) }
    end

    def volumes_to_detach(instance)
      (volumes_attached_to(instance) - volumes).collect { |v| @options.find_volume(v) }
    end

    def volume_change_count(instance)
      volumes_to_attach(instance).size + volumes_to_detach(instance).size
    end

    def packages_to_install(instance)
      packages - packages_installed_on(instance)
    end

    def packages_to_remove(instance)
      packages_installed_on(instance) - packages
    end

    def package_change_count(instance)
      packages_to_install(instance).size + packages_to_remove(instance).size
    end

    private 
      def packages
        @properties['packages'].to_set
      end

      def volumes
        @options.filter_volume_ids(@properties['volumes'])
      end

      def packages_installed_on(instance)
        instance ? instance.packages : Set[]
      end

      def volumes_attached_to(instance)
        instance ? @options.filter_volume_ids(instance.volumes) : Set[]
      end
  end
end
