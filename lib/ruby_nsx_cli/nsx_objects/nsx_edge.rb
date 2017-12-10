require_relative 'nsxobject'

module RubyNsxCli
  class NSXEdge < NSXObject

    INTERFACE_TYPES = %w[internal uplink]


    # Attaches an interface to the specified edge
    #
    # @param edge_id [String] Edge ID to
    # @param name [String] Name of the interface
    # @param primary_address [Integer] Primary IP address for the interface
    # @param subnet_mask [String] Subnet mask for the network that the interface is attached to
    # @param mtu [Integer] Maximum transmission unit for the interface
    # @param connected_to_id [String] ID of the virtualwire or port group to attach the interface to
    # @param type [Type] Network link type; either 'internal' or 'uplink'
    # @return [String] Interface XML configuration from the NSX API
    def attach_interface(edge_id:, name:, primary_address:, subnet_mask:, mtu:, connected_to_id:, type:)
      api_endpoint = "/api/4.0/edges/#{edge_id}/interfaces/?action=patch"

      interface_hash = {
          :name => name,
          :primary_address => primary_address,
          :subnet_mask => subnet_mask,
          :mtu => mtu || 1500,
          :connected_to_id => connected_to_id,
          :type => type
      }

      validate_edge_args(interface_hash, edge_id)
      raise "The interface type must be one of: #{INTERFACE_TYPES.to_s}" if !INTERFACE_TYPES.include?(interface_hash[:type])

      @logger.info("Checking if interface already exists on edge: #{edge_id}")
      if (interface = check_interface_exists(edge_id, connected_to_id))
        @logger.info("Skipping interface - interface already exists (edgeId: #{edge_id} connectedToId: #{connected_to_id})")
        return interface
      end


      interface_obj = OpenStruct.new(interface_hash)
      payload = render_template('/templates/interface/interfaces.xml.erb', interface_obj)

      post(:api_endpoint => api_endpoint, :payload => payload)
    end

    # Adds a DHCP relay agent to the specified edge for the specified vNIC
    # This method is not safe to run concurrently
    #
    # @param edge_id [String] Edge Id to add the DHCP agent to
    # @param gi_address [String] Gateway IP address
    # @param vnic_index [Integer] vNIC index of the interface on the specified edge to add the DHCP relay agent
    # @return [RestClient::Response] Response from the NSX API
    def add_dhcp_agent(edge_id, vnic_index, gi_address)

      api_endpoint = "/api/4.0/edges/#{edge_id}/dhcp/config/relay"

      dhcp_agent_hash = {
          :vnic_index => vnic_index,
          :gi_address => gi_address
      }

      validate_edge_args(dhcp_agent_hash, edge_id)

      dhcp_agent_obj = OpenStruct.new(dhcp_agent_hash)
      dhcp_agent_xml = render_template('/templates/dhcp/relayagent.xml.erb', dhcp_agent_obj)

      # The DHCP configuration must be retrieved as the put operation overrides the current config
      # There does not seem to be an alternative way of doing this
      current_dhcp_config = get("/api/4.0/edges/#{edge_id}/dhcp/config/relay")

      @logger.info("Checking if DHCP agent already exists on edge: #{edge_id}")
      if check_dhcp_agent_exists(current_dhcp_config, vnic_index, gi_address)
        @logger.info("Skipping Agent - DHCP agent already exists (vnicIndex: #{vnic_index} giAddress #{gi_address})")
        return
      end

      @logger.info("Adding Agent (vnicIndex: #{vnic_index} giAddress #{gi_address})")

      # Grandparent xml node must be provided in the case that the parent node does not exist
      # i.e. <relayAgents /> does not exist if there are no current relay agents on the edge
      payload = inject_xml(current_dhcp_config, 'relay', 'relayAgents', dhcp_agent_xml)

      # Strip out XML pi at top of response to prevent 500 errors due to bad formatting of XML payload
      payload = strip_xml_root_pi(payload)

      put(:api_endpoint => api_endpoint, :payload => payload)
    end


    # Adds a DHCP IP pool agent to the specified edge
    # This creates a simple dhcp pool as it only allows a small number of the available options to be specified
    #
    # @param edge_id [String] Edge ID to add the DHCP pool
    # @param ip_range [String] Range of IP addresses to include in the DHCP pool. i.e. 192.168.10.2-192.168.10.62
    # @param default_gateway [String] Default gateway for the network that the agent is providing DHCP to
    # @param primary_name_server [String] Primary DNS
    # @param secondary_name_server [String] Secondary DNS
    # @param lease_time [Integer] DHCP lease time. Defaults to 3600
    # @return [RestClient::Response] Response from the NSX API
    def add_simple_dhcp_pool(edge_id:, ip_range:, default_gateway:, domain_name:, primary_name_server:, secondary_name_server:, lease_time:)

      api_endpoint = "/api/4.0/edges/#{edge_id}/dhcp/config/ippools"

      simple_dhcp_pool_hash = {
          :ip_range => ip_range,
          :default_gateway => default_gateway,
          :domain_name => domain_name,
          :primary_name_server => primary_name_server,
          :secondary_name_server => secondary_name_server,
          :lease_time => lease_time || 3600
      }

      validate_edge_args(simple_dhcp_pool_hash, edge_id)
      @logger.info("Checking if DHCP IP pool already exists on edge: #{edge_id}")
      if (ip_pool_id = check_simple_dhcp_pool_exists(edge_id, ip_range))
        @logger.info("Skipping DHCP IP Pool - already exists (edgeId: #{edge_id} ipRange: #{ip_range})")
        return ip_pool_id
      end

      simple_dhcp_pool_obj = OpenStruct.new(simple_dhcp_pool_hash)
      payload = render_template('/templates/dhcp/simple-dhcp-pool.xml.erb', simple_dhcp_pool_obj)

      post(:api_endpoint => api_endpoint, :payload => payload)
    end

    # Checks if the specified edge already has the DHCP IP pool by checking if the ip_range has already been specified
    #
    # @param edge_id [String] Edge ID to check if the IP pool already exists
    # @param ip_range [String] IP range of the DHCP IP pool
    # @return [String] the ID of the DHCP pool if it exists; otherwise nil
    def check_simple_dhcp_pool_exists(edge_id, ip_range)
      api_endpoint = "/api/4.0/edges/#{edge_id}/dhcp/config"
      doc = Nokogiri::XML(get(api_endpoint))
      ip_pools = doc.css('ipPool')
      ip_pools.map {|ip_pool| return ip_pool.at('poolId').text if ip_pool.at('ipRange').text == ip_range}
      return nil
    end

    # Checks if the specified edge already has the port group or virtualwire attached
    #
    # @param edge_id [String] Edge ID to check if the interface is attached to
    # @param connected_to_id [String] ID of the virtualwire or port group of the interface
    # @return [String] XML string containing the configuration for the interface if it exists; otherwise nil
    def check_interface_exists(edge_id, connected_to_id)
      api_endpoint = "/api/4.0/edges/#{edge_id}/interfaces"
      doc = Nokogiri::XML(get(api_endpoint))
      interfaces = doc.css('interface')
      interfaces.map {|interface| return strip_xml_root_pi(interface) if interface.at('connectedToId').text == connected_to_id}
      return nil
    end


    # Checks if a DHCP relay agent already exists within the specified XML document
    #
    # @param xml [String] XML document to check for the DHCP agent
    # @param vnic_index [String] vNIC index of the DHCP agent on the edge it is attached to
    # @param gi_address [String] Gateway IP address for the DHCP agent
    # @return [Boolean] True if the agent exists; otherwise false
    def check_dhcp_agent_exists(xml, vnic_index, gi_address)
      doc = Nokogiri::XML(xml)
      agents = doc.css('relayAgent')

      agents.each do |agent|
        agent_vnic_index = agent.css('vnicIndex').text
        agent_gi_address = agent.css('giAddress').text
        if vnic_index == agent_vnic_index && gi_address == agent_gi_address
          return true
        end
      end

      return false
    end


    def validate_edge_args(arg_hash, edge_id)
      errors = []
      errors << 'Error: Edge ID must be specified' if edge_id.nil?
      arg_hash.map {|k, v| errors << "Error: Argument: #{arg.to_s} must be specified" if v.nil?}
      raise errors.to_s if errors.length > 0
    end

  end
end