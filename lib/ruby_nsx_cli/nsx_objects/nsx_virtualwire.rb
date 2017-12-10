require_relative 'nsxobject'

module RubyNsxCli

  class NSXVirtualWire < NSXObject

    CONTROL_PLANE_MODES = %w[
        UNICAST_MODE
        MULTICAST_MODE
        HYBRID_MODE
    ]


    # Creates an NSX virtualwire with the provided arguments
    #
    # @param name [String] Name of the virtualwire
    # @param scope_id [String] vdnscope on which the virtualwire will be added to
    # @param description [String] Optional description for the virtualwire
    # @param tenant_id [String]
    # @param control_plane_mode [String] one of 'UNICAST_MODE', 'MULTICAST_MODE', 'HYBRID_MODE'. Defaults to 'UNICAST_MODE'
    # @return [String] virtualwire ID.
    def create(name:, scope_id:, description:, tenant_id:, control_plane_mode:)

      @logger.info("Attempting to create new virtualwire (name: #{name}, scopeId: #{scope_id})")

      virtual_wire_hash = {
          :name => name,
          :description => description,
          :tenant_id => tenant_id || 'virtual wire tenant',
          :control_plane_mode => control_plane_mode || 'UNICAST_MODE'
      }

      validate_create_args(virtual_wire_hash, scope_id)

      @logger.info("Checking if virtualwire already exists (name: #{name}, scopeId: #{scope_id})")
      if (vwire_id = check_virtual_wire_exists(name, scope_id))
        @logger.info("Skipping virtualwire creation - virtual wire already exists (name: #{name}, scopeId: #{scope_id})")
        return vwire_id
      end

      @logger.info("Adding virtual wire (name: #{name}, scopeId: #{scope_id})")

      virtual_wire_obj = OpenStruct.new(virtual_wire_hash)
      api_endpoint = "/api/2.0/vdn/scopes/#{scope_id}/virtualwires"
      payload = render_template('/templates/virtualwire/virtualwire.xml.erb', virtual_wire_obj)

      post(:api_endpoint => api_endpoint, :payload => payload)
    end

    # Deletes a virtualwire
    #
    # @param virtualwire_id [String] ID of the virtualwire
    # @return [String] virtualwire ID if it exists; otherwise nil
    def delete(virtualwire_id)
      raise 'You must specify the virtual wire id to be deleted' if !virtualwire_id
      api_endpoint = "/api/2.0/vdn/virtualwires/#{virtualwire_id}"
      super(:api_endpoint => api_endpoint)
    end

    # Checks if a virtaul wire exists by querying the API for a list of virtual wires for the specified scope
    #
    # @param name [String] Name of the virtualwire
    # @param scope_id [String] vdnscope to check for the virtualwire
    # @return [String] virtualwire id if it exists; otherwise nil
    def check_virtual_wire_exists(name, scope_id)
      api_endpoint = "/api/2.0/vdn/scopes/#{scope_id}/virtualwires?startindex=0&pagesize=1000"
      xml = get(api_endpoint)
      doc = Nokogiri::XML(xml)
      virtualwires = doc.css('virtualWire')
      virtualwires.map {|vwire| return vwire.at('objectId').text if vwire.at('name').text == name}
      return nil
    end


    def validate_create_args(virtual_wire_hash, scope_id)
      errors = []
      if !NSXVirtualWire::CONTROL_PLANE_MODES.include?(virtual_wire_hash[:control_plane_mode])
        errors << "Error: Control Plane Mode must be one of [#{NSXVirtualWire::CONTROL_PLANE_MODES.to_s}]"
      end

      errors << 'Error: Scope ID must be specified' if scope_id.nil?
      virtual_wire_hash.map {|k, v| errors << "Error: Argument: #{arg.to_s} must be specified" if v.nil?}
      raise errors.to_s if errors.length > 0
    end

  end
end