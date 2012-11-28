require 'route53'

module Awsome
  module R53
    def self.connection
      @@connection ||= Route53::Connection.new(Awsome.config.aws_access_key, Awsome.config.aws_secret_key)
    end
    def self.zones
      self.connection.get_zones
    end
    def self.find_zone(zone_name)
      self.zones.find { |z| z.name == zone_name }
    end
    def self.find_cname(zone_name, name)
      find_zone(zone_name).get_records('CNAME').find { |r| r.name == name }
    end
    def self.redefine_cname(zone_name, name, value)
      if record = find_cname(zone_name, name)
        record.update(nil, nil, nil, [value], nil)
      else
        Route53::DNSRecord.new(name, 'CNAME', 300, [value], find_zone(zone_name)).create
      end
    end
  end
end
