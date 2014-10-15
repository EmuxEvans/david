require 'david/server/mapping'
require 'david/server/utility'

module David
  class Server
    module Response
      include Mapping
      include Utility

      # Freeze some WSGI env keys.
      REMOTE_ADDR     = 'REMOTE_ADDR'.freeze
      REMOTE_PORT     = 'REMOTE_PORT'.freeze
      REQUEST_METHOD  = 'REQUEST_METHOD'.freeze
      SCRIPT_NAME     = 'SCRIPT_NAME'.freeze
      PATH_INFO       = 'PATH_INFO'.freeze
      QUERY_STRING    = 'QUERY_STRING'.freeze
      SERVER_NAME     = 'SERVER_NAME'.freeze
      SERVER_PORT     = 'SERVER_PORT'.freeze
      CONTENT_LENGTH  = 'CONTENT_LENGTH'.freeze
      CONTENT_TYPE    = 'CONTENT_TYPE'.freeze
      HTTP_ACCEPT     = 'HTTP_ACCEPT'.freeze

      # Freeze some Rack env keys.
      RACK_VERSION      = 'rack.version'.freeze
      RACK_URL_SCHEME   = 'rack.url_scheme'.freeze
      RACK_INPUT        = 'rack.input'.freeze
      RACK_ERRORS       = 'rack.errors'.freeze
      RACK_MULTITHREAD  = 'rack.multithread'.freeze
      RACK_MULTIPROCESS = 'rack.multiprocess'.freeze
      RACK_RUN_ONCE     = 'rack.run_once'.freeze
      RACK_LOGGER       = 'rack.logger'.freeze

      # Freeze some Rack env values.
      EMPTY_STRING          = ''.freeze
      CONTENT_TYPE_JSON     = 'application/json'.freeze
      CONTENT_TYPE_CBOR     = 'application/cbor'.freeze
      RACK_URL_SCHEME_HTTP  = 'http'.freeze

      protected

      def respond(host, port, request)
        env = basic_env(host, port, request)
        logger.debug env

        code, options, body = @app.call(env)

        ct = content_type(options)
        body = body_to_string(body)

        body.close if body.respond_to?(:close)

        if @cbor
          body = body_to_cbor(body)
          ct = CONTENT_TYPE_CBOR
        end

        response = initialize_response(request)

        response.mcode = http_to_coap_code(code)
        response.payload = body

        response.options[:etag] = etag(options, 4)
        response.options[:content_format] = 
          CoAP::Registry.convert_content_format(ct)

        response
      end

      def basic_env(host, port, request)
        {
          REMOTE_ADDR       => host,
          REMOTE_PORT       => port.to_s,
          REQUEST_METHOD    => coap_to_http_method(request.mcode),
          SCRIPT_NAME       => EMPTY_STRING,
          PATH_INFO         => path_encode(request.options[:uri_path]),
          QUERY_STRING      => query_encode(request.options[:uri_query])
                                  .gsub(/^\?/, ''),
          SERVER_NAME       => @host,
          SERVER_PORT       => @port.to_s,
          CONTENT_LENGTH    => request.payload.size.to_s,
          CONTENT_TYPE      => CONTENT_TYPE_JSON,
          HTTP_ACCEPT       => CONTENT_TYPE_JSON,
          RACK_VERSION      => [1, 2],
          RACK_URL_SCHEME   => RACK_URL_SCHEME_HTTP,
          RACK_INPUT        => StringIO.new(request.payload),
          RACK_ERRORS       => $stderr,
          RACK_MULTITHREAD  => true,
          RACK_MULTIPROCESS => true,
          RACK_RUN_ONCE     => false,
          RACK_LOGGER       => @logger,
        }
      end

      def initialize_response(request)
        type = request.tt == :con ? :ack : :non

        CoAP::Message.new \
          tt: type,
          mcode: 2.00,
          mid: request.mid,
          token: request.options[:token]
      end
    end
  end
end
