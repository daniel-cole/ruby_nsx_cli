# RubyNsxCli

This gem is in early stages of development and has only a small set of VMWare's NSX
API currently implemented.

The main focus for developing this gem was to provide a simple way to automate network creation using the NSX API.

## Features

1. Creation and deletion of virtual wires
2. Attaching interfaces an edge
3. Adding DHCP relay agents to an edge
4. Creating a DHCP IP pool on an edge (This is limited in that it only provides a subset of the available options)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_nsx_cli'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruby_nsx_cli

## Usage

Create a new virtual wire:
```ruby
virtualwire = RubyNsxCli::NSXVirtualWire.new

virtualwire_args = {
  :name => 'api-test-wire-1',
  :scope_id => 'vdnscope-1',
  :description => 'virtual wire for api testing',
  :tenant_id => nil,
  :control_plane_mode => nil
}

virtualwire.create(virtualwire_args)
```

Attach an interface to an edge:
```ruby
edge = RubyNsxCli::NSXEdge.new


interface_args = {
  :edge_id => 'edge-5',
  :name => 'api-test-lif-1',
  :primary_address => '10.250.30.1',
  :subnet_mask => '255.255.255.0',
  :mtu => '1500',
  :connected_to_id => virtualwire_id,
  :type => 'internal'
}

edge.attach_interface(interface_args)
```

Chain commands together to create a new virtualwire, attach the interface and create a DHCP pool:
```ruby
# First, create the virtual wire 
virtualwire = RubyNsxCli::NSXVirtualWire.new
virtualwire_args = {
  :name => 'api-test-wire-attach-dhcp-1',
  :scope_id => 'vdnscope-1',
  :description => 'virtual wire for api testing',
  :tenant_id => nil,
  :control_plane_mode => nil
}
virtualwire_id = virtualwire.create(virtualwire_args)

# Second, attach the interface to the specified edge
edge = RubyNsxCli::NSXEdge.new
gateway_address = '10.250.31.1'

interface_args = {
  :edge_id => 'edge-5',
  :name => 'api-test-lif-dhcp-1',
  :primary_address => gateway_address,
  :subnet_mask => '255.255.255.0',
  :mtu => '1500',
  :connected_to_id => virtualwire_id,
  :type => 'internal'
}

# The response from attaching the interface will contain the vnic index required for adding a DHCP relay
response = edge.attach_interface(interface_args)

# Parse the vNIC index from the response given when attaching the interface
vnic_index = edge.get_attr_text_from_xml(response, 'index')

# Finally, add the dhcp agent to the edge
edge.add_dhcp_agent(edge_id, vnic_index, gateway_address)
```



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

Please note that you will need to set the following environment variables before running `rake test`:
1. NSX_USERNAME
2. NSX_PASSWORD
3. NSX_MANAGER_URL
4. NSX_TEST_ESG_ID
5. NSX_TEST_DLR_ID

How to run a single test using rake:
```
rake test TEST=test/nsx_edge_test.rb TESTOPTS="--name=test_add_dhcp_relay -v"
```


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/daniel-cole/ruby_nsx_cli. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
