require 'terminal-table'

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

    def self.to_table(matches, title='Matches')
      rows = []

      # enumerate match rows
      matches.each do |signature, match|
        match[:i_pool].each_with_index do |i, idx|
          r = match[:r_pool][idx]
          rows << [
            r.nil? ? 'terminate' : 'deploy',
            i.nil? ? '(new)' : i.id,
            (r || i).packages.to_a.join("\n"),
            (r || i).volumes.to_a.join("\n"),
            (r || i).elbs.collect{|e| e.is_a?(String) ? e : e.name}.join("\n"),
            (r || i).ami_id,
            (r || i).key,
            (r || i).instance_type,
            (r || i).availability_zone,
            (r || i).security_group_ids,
          ]
          rows << :separator
        end
      end
      
      # remove last unnecessary separator
      rows.pop if rows.any?

      headings = %w(action instance packages volumes elbs ami key type zone secgroup)
      Terminal::Table.new :headings => headings, :rows => rows, :title => title
    end

    private

      def best_match(signature)
        i_pool = @instance_pools[signature]
        r_pool = @requirement_pools[signature]

        best = nil

        permute i_pool do |i_pool_perm|
          best = winner(best, build_match(i_pool_perm, r_pool))
        end

        best
      end

      def winner(m1, m2)
        return m1 if m2.nil?
        return m2 if m1.nil?
        raise 'cannot declare winner between 2 nil contestants' if m1.nil? && m2.nil?
        return m1 if m1[:v_delta] < m2[:v_delta]
        return m2 if m2[:v_delta] < m1[:v_delta]
        return m1 if m1[:p_delta] < m2[:p_delta]
        return m2 if m2[:p_delta] < m1[:p_delta]
        return m1
      end

      def build_match(i_pool, r_pool)
        v_delta = 0
        p_delta = 0

        i_pool.each_with_index do |i, index| 
          r = r_pool[index]
          if r
            v_delta += r.volume_change_count(i) 
            p_delta += r.package_change_count(i)
          end
        end

        return { 
          v_delta: v_delta,
          p_delta: p_delta,
          i_pool: i_pool,
          r_pool: r_pool
        }
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
