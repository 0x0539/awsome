module Awsome
  class Matchmaker
    def initialize(instances, requirements)
      @requirement_pools = requirements.instances.reject do |i| 
        requirements.options.except_instance_ids.include?(i.properties['instance_id']) 
      end.group_by { |i| signature_for(i) }

      @instance_pools = instances.reject do |i| 
        requirements.options.except_instance_ids.include?(i.properties['instance_id']) 
      end.group_by { |i| signature_for(i) }

      @signatures = @requirement_pools.keys.to_set + @instance_pools.keys.to_set

      @signatures.each do |s|
        @requirement_pools[s] ||= []
        @instance_pools[s] ||= []

        # nil indicates new instance will be brought up
        shortage = @requirement_pools[s].size - @instance_pools[s].size
        @instance_pools[s] += [nil]*shortage if shortage > 0
      end
    end

    @@signature_fields = %w( ami_id key instance_type availability_zone security_group_ids )

    def signature_for(instance)
      @@signature_fields.collect { |k| instance.properties[k] }.join(',')
    end

    def matches
      @signatures.reduce({}) { |memo, s| memo.merge(s => best_match(s)) }
    end

    private

      def best_match(signature)
        i_pool = @instance_pools[signature]
        r_pool = @requirement_pools[signature]

        best = nil

        permute i_pool do |i_pool_perm|
          best = score_match(i_pool_perm, r_pool, best)
        end

        best
      end

      def score_match(i_pool, r_pool, best)
        v_delta = 0
        p_delta = 0

        i_pool.each_with_index do |i, index| 
          r = r_pool[index]
          if r
            v_delta += r.volume_change_count(i) 
            p_delta += r.package_change_count(i)
          end
        end

        top_score({ 
          v_delta: v_delta,
          p_delta: p_delta,
          i_pool: i_pool,
          r_pool: r_pool
        }, best)
      end

      def top_score(*scores)
        scores.sort_by do |s1, s2| 
          case
          when s1.nil? && s2.nil? then 0
          when s2.nil? then -1
          when s1.nil? then 1
          when s1[:v_delta] < s2[:v_delta] then -1
          when s1[:v_delta] > s2[:v_delta] then 1
          when s1[:p_delta] < s2[:p_delta] then -1
          when s1[:p_delta] > s2[:p_delta] then 1
          else 0
          end
        end.first
      end

      def permute(array, permutation=[], &block)
        if array.empty?
          yield(permutation.clone)
        else
          0.upto(array.length - 1) do |i| 
            permutation << array.slice!(i)
            permute(array, permutation, &block)
            array.insert(i, permutation.pop)
          end
        end
      end
  end
end
