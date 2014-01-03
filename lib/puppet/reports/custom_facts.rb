require 'uri'
require 'json'
require 'yaml'
require 'puppet'
require 'net/https'

Puppet::Reports.register_report(:custom_facts) do

  def get_settings
    settings_file = File.join([File.dirname(Puppet.settings[:config]), "custom_facts.yaml"])

    if File.exist?(settings_file)
      parse_file = YAML.load(settings_file)
    else
      raise(Puppet::ParseError, "Custom reports config file #{settings_file} not readable") 
    end

    return parse_file
  end


  def update_riak(node, data)

    options = get_settings()
    request = Net::HTTP.new(options[:riak_host], options[:riak_port])

    request.open_timeout = 2
    request.read_timeout = 2

    filtered = Hash.new
    data.each do |k, v|
      if not options[:exclude_facts].include? k
        filtered[k] = v
      end
    end

    begin
      new_data = {'updated'    => Time.now.to_s,
                  'updated_ts' => Time.now.to_i,
                  'data'       => filtered}
      put_data = request.post("/riak/facts/#{node}", new_data.to_json, {'Content-Type' => 'application/json'})
    rescue Exception => e
      return "Error submitting data to riak: #{e}"
    end

    return true
  end


  def process

    client  = self.host
    config  = get_settings()
    request = Net::HTTP.new(config[:master_host], config[:master_port])

    request.open_timeout = 2
    request.read_timeout = 2
    request.use_ssl      = true
    request.verify_mode  = OpenSSL::SSL::VERIFY_NONE

    begin
      facts = YAML.load(request.get("/#{config[:environment]}/facts/#{client}",
                                    {"Accept"=> "yaml"}).body)
      data  = update_riak(self.host, facts.values)

      if data
        Puppet.info "Posted custom facts to riak"
      else
        Puppet.notice data
      end

    rescue Exception => e
      Puppet.notice "Error retrieving REST facts for bios_report (expected for first run): #{e}"
    end

  end

end
