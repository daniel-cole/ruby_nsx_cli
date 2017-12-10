require "test_helper"

class NSXVirtualWireTest < Minitest::Test
  def test_create_and_delete_virtual_wire
    virtualwire = RubyNsxCli::NSXVirtualWire.new()

    virtualwire_args = {
        :name => 'api-test-wire-1',
        :scope_id => 'vdnscope-1',
        :description => 'virtual wire for api testing',
        :tenant_id => nil,
        :control_plane_mode => nil
    }

    virtualwire_id = virtualwire.create(virtualwire_args)

    if virtualwire_id.nil? || (virtualwire_id =~ /virtualwire*/).nil?
      assert(false, "expected virtualwire creation to return virtualwire-id instead got: #{virtualwire_id}")
    end


    response = virtualwire.delete(virtualwire_id)
    assert_equal(response.code, 200, "expected deletion to return http code 200, instead got #{response.code}")

  end

end
