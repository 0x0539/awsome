module Awsome
  class RequirementsOptions
    def initialize(requirements)
      @options = (requirements['options'] || {}).clone
    end
    def only_volume_ids
      @options['volumes'].collect { |v| v['id'] }.to_set
    end
    def except_instance_ids
      (@options['except_instance_ids'] || []).to_set
    end
    def filter_volume_ids(ids)
      ids = ids.to_set unless ids.is_a?(Set)
      only_volume_ids.any? ? only_volume_ids & ids : ids
    end
    def find_volume(volume_id)
      @options['volumes'].find { |v| v['id'] == volume_id }
    end
  end
end
