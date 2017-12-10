require 'rest-client'
require 'nokogiri'
require 'erb'
require 'yaml'
require 'logger'

module RubyNsxCli
  class NSXObject

    XML_HEADER = {'Content-Type': 'application/xml'}

    def initialize(**args)
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::DEBUG

      @nsx_manager_url = args[:nsx_manager_url] || ENV['NSX_MANAGER_URL'] || (raise 'NSX Manager URL not specified!')
      @nsx_username = args[:nsx_username] || ENV['NSX_USERNAME'] || (raise 'NSX Username not specified!')
      @nsx_password = args[:nsx_password] || ENV['NSX_PASSWORD'] || (raise 'NSX Password not specified!')
      @ssl_check = args[:verify_ssl] ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    end

    # Deletes an NSX object using the NSX API.
    #
    # @param api_endpoint [String] NSX endpoint to send the request
    # @return [RestClient::Response] Response from the NSX API.
    def delete(api_endpoint:)

      @logger.info("Deleting NSX object: #{self.class}...")
      @logger.debug("Sending request to: #{@nsx_manager_url}...")
      @logger.debug("API endpoint is: #{api_endpoint}")

      begin
        resp = create_new_request(api_endpoint, nil).delete

        if resp.code >= 200 && resp.code < 300
          @logger.info("Successfully deleted NSX object: #{self.class}")
          return resp
        else
          raise "Unexpected return code during NSX object creation: #{self.class} returned #{resp.code}"
        end

      rescue RestClient::ExceptionWithResponse => err
        puts "Failed to create NSX object: #{self.class}"
        puts "Response code: #{err.http_code}"
        puts "Response: #{err.message}"
        return resp
      end

    end

    # Sends a post request to the NSX API. Usually to update an object.
    #
    # @param api_endpoint [String] the NSX endpoint to send the request
    # @param payload [String] the payload to send to the `api_endpoint`
    # @return [RestClient::Response] the response from the NSX API.
    def post(api_endpoint:, payload:)
      @logger.info("Updating NSX object: #{self.class}...")
      @logger.debug("Payload is: \n#{payload}")
      @logger.debug("API endpoint is: #{api_endpoint}")
      @logger.debug("Sending request to: #{@nsx_manager_url}...")

      begin

        resp = create_new_request(api_endpoint, XML_HEADER).post(payload)

        if resp.code >= 200 && resp.code < 300
          @logger.info("Successfully updated NSX object: #{self.class}")
          return resp
        else
          raise "Unexpected return code during NSX object update: #{self.class} returned #{resp.code}"
        end

      rescue RestClient::ExceptionWithResponse => err
        @logger.info("Failed to update NSX object: #{self.class}")
        @logger.info("Response code: #{err.http_code}")
        @logger.info("Response: #{err.message}")
        return resp
      end

    end

    # Sends a post request to the NSX API. Usually to update an object.
    #
    # @param api_endpoint [String] the NSX endpoint to send the request
    # @param payload [String] the payload to send to the `api_endpoint`
    # @return [RestClient::Response] the response from the NSX API.
    def put(api_endpoint:, payload:)
      @logger.info("Updating NSX object (HTTP put): #{self.class}")
      @logger.debug("Payload is: \n#{payload}")
      @logger.debug("API endpoint is: #{api_endpoint}")
      @logger.debug("Sending request to: #{@nsx_manager_url}...")


      begin
        resp = create_new_request(api_endpoint, XML_HEADER).put(payload)

        if resp.code >= 200 && resp.code < 300
          @logger.info("Successfully put NSX object: #{self.class}")
          return resp
        else
          raise "Unexpected return code during NSX object put: #{self.class} returned #{resp.code}"
        end

      rescue RestClient::ExceptionWithResponse => err
        @logger.error("Failed to put NSX object: #{self.class}")
        @logger.error("Response code: #{err.http_code}")
        @logger.error("Response: #{err.message}")
        return resp
      end

    end

    # Sends a get request to the NSX API.
    #
    # @param api_endpoint [String] NSX endpoint to send the request
    # @return [RestClient::Response] Response from the NSX API.
    def get(api_endpoint)
      resp = create_new_request(api_endpoint, nil).get
      return resp
    end

    # Helper method that creates the initial RestClient::Request object.
    #
    # @param api_endpoint the NSX endpoint to send the request
    # @param headers the headers to include in the request
    # @return [RestClient::Request] the initial request object to be used to call REST methods.
    def create_new_request(api_endpoint, headers)
      return RestClient::Resource.new(
          "https://#{@nsx_manager_url}/#{api_endpoint}",
          :verify_ssl => @ssl_check,
          :user => @nsx_username,
          :password => @nsx_password,
          :headers => headers
      )
    end

    # Inserts an XML block into the provided XML at the parent node
    # If the parent node does not exist, then the parent node will be created
    # with the node injected into the grandparent node
    # Returns the updated xml with the node injected
    #
    # @param xml [String] the NSX endpoint to send the request
    # @param grandparent [String] the grandparent attribute of the node to insert;
    # only required if the parent node is not included in the provided xml string
    # @param parent [String] the parent attribute of the node to insert
    # @param node [String] the payload to send to `:api_endpoint`
    # @return [String] the original XML string including the inserted node.
    def inject_xml(xml, grandparent, parent, node)
      doc = Nokogiri::XML(xml)
      parent_xml = doc.at_css(parent)
      if parent_xml.nil?
        grandparent_xml = doc.at_css(grandparent)
        raise "No valid parent to insert XML block into with nodes provided: #{parent_xml}, #{grandparent_xml}" if grandparent_xml.nil?
        parent_xml = Nokogiri::XML::Node.new(parent, doc)
        grandparent_xml << parent_xml
      end
      parent_xml << node
      return doc
    end

    # Removes the <?xml version="1.0" encoding="UTF-8"?> processing instruction from the start of an XML string
    # The new line character left in place is also removed to prevent issues when sending a payload to the NSX API
    # which includes this string
    #
    # @param xml [String] an XML string that includes the processing instruction '<?xml version="1.0" encoding="UTF-8"?>'
    # @return [String] the XML string without the processing instruction
    def strip_xml_root_pi(xml)
      frag = Nokogiri::XML::DocumentFragment.parse(xml)
      frag.xpath('processing-instruction()').remove
      return frag.to_s.sub("\n", '') # remove new line generated from removing root pi
    end

    def get_attr_text_from_xml(xml, attr)
      doc = Nokogiri::XML(xml)
      return doc.at(attr).text
    end

    # Renders the specified erb file using the provided object
    #
    # @param template [String] the relative path to the template
    # @param object [Object] the OpenStruct object that contains the key + values for rendering the template
    # @return [Object] the rendered template
    def render_template(template, object)
      renderer = ERB.new(File.read(File.dirname(__FILE__) + template))
      return renderer.result(object.instance_eval {binding})
    end

  end
end
