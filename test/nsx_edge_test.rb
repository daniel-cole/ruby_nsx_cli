require "test_helper"

class NSXEdgeTest < Minitest::Test
  def test_attach_interface
    edge_id = ENV['NSX_TEST_DLR_ID']

    virtualwire = RubyNsxCli::NSXVirtualWire.new

    virtualwire_args = {
        :name => 'api-test-wire-attach-lif-1',
        :scope_id => 'vdnscope-1',
        :description => 'virtual wire for api testing',
        :tenant_id => nil,
        :control_plane_mode => nil
    }

    virtualwire_id = virtualwire.create(virtualwire_args)

    edge = RubyNsxCli::NSXEdge.new

    interface_args = {
        :edge_id => edge_id,
        :name => 'api-test-lif-1',
        :primary_address => '10.250.30.1',
        :subnet_mask => '255.255.255.0',
        :mtu => '1500',
        :connected_to_id => virtualwire_id,
        :type => 'internal'
    }

    edge.attach_interface(interface_args)

  end

  def test_add_dhcp_relay

    edge_id = ENV['NSX_TEST_DLR_ID']


    # first create virtualwire to attach to edge
    virtualwire = RubyNsxCli::NSXVirtualWire.new
    virtualwire_args = {
        :name => 'api-test-wire-attach-dhcp-1',
        :scope_id => 'vdnscope-1',
        :description => 'virtual wire for api testing',
        :tenant_id => nil,
        :control_plane_mode => nil
    }
    virtualwire_id = virtualwire.create(virtualwire_args)

    # attach the virtualwire to the edge
    edge = RubyNsxCli::NSXEdge.new
    gateway_address = '10.250.31.1'

    interface_args = {
        :edge_id => edge_id,
        :name => 'api-test-lif-dhcp-1',
        :primary_address => gateway_address,
        :subnet_mask => '255.255.255.0',
        :mtu => '1500',
        :connected_to_id => virtualwire_id,
        :type => 'internal'
    }

    # the response from attaching the interface will contain the vnic index required for adding a dhcp relay
    response = edge.attach_interface(interface_args)

    # parse the vnic index from the response given when attaching the interface
    vnic_index = edge.get_attr_text_from_xml(response, 'index')

    # finally add the dhcp agent to the edge
    edge.add_dhcp_agent(edge_id, vnic_index, gateway_address)

  end

  def test_add_dhcp_pool
    edge_id = ENV['NSX_TEST_ESG_ID']

    edge = RubyNsxCli::NSXEdge.new

    dhcp_pool_args = {
        :edge_id => edge_id,
        :ip_range => '10.250.32.2-10.250.32.254',
        :subnet_mask => '255.255.255.0',
        :default_gateway => '10.250.32.1',
        :domain_name => 'api.test250',
        :primary_name_server => '8.8.8.8',
        :secondary_name_server => '8.8.4.4',
        :lease_time => nil
    }

    edge.add_simple_dhcp_pool(dhcp_pool_args)

  end

end