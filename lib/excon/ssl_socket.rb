module Excon
  class SSLSocket < Socket

    HAVE_NONBLOCK = [:connect_nonblock, :read_nonblock, :write_nonblock].all? {|m|
      OpenSSL::SSL::SSLSocket.public_method_defined?(m)
    }

    def initialize(data = {})
      super

      # create ssl context
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.ciphers = @data[:ciphers]
      ssl_context.ssl_version = @data[:ssl_version] if @data[:ssl_version]
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # maintain existing API
      certificate_path = @data[:client_cert] || @data[:certificate_path]
      private_key_path = @data[:client_key] || @data[:private_key_path]

      if certificate_path && private_key_path
        ssl_context.cert = OpenSSL::X509::Certificate.new(File.read(certificate_path))
        ssl_context.key = OpenSSL::PKey::RSA.new(File.read(private_key_path))
      elsif @data.has_key?(:certificate) && @data.has_key?(:private_key)
        ssl_context.cert = OpenSSL::X509::Certificate.new(@data[:certificate])
        ssl_context.key = OpenSSL::PKey::RSA.new(@data[:private_key])
      end

      if @data[:proxy]
        request = 'CONNECT ' << @data[:host] << port_string(@data) << Excon::HTTP_1_1
        request << 'Host: ' << @data[:host] << port_string(@data) << Excon::CR_NL

        if @data[:proxy][:password] || @data[:proxy][:user]
          auth = ['' << @data[:proxy][:user].to_s << ':' << @data[:proxy][:password].to_s].pack('m').delete(Excon::CR_NL)
          request << "Proxy-Authorization: Basic " << auth << Excon::CR_NL
        end

        request << 'Proxy-Connection: Keep-Alive' << Excon::CR_NL

        request << Excon::CR_NL

        puts request.inspect

        # write out the proxy setup request
        @socket.write(request)

        # eat the proxy's connection response
        Excon::Response.parse(@socket, { :expects => 200, :method => "CONNECT" })
      end

      # convert Socket to OpenSSL::SSL::SSLSocket
      @socket = OpenSSL::SSL::SSLSocket.new(@socket, ssl_context)
      @socket.sync_close = true
      @socket.connect

      # Server Name Indication (SNI) RFC 3546
      if @socket.respond_to?(:hostname=)
        @socket.hostname = @data[:host]
      end

      # verify connection
      # if @data[:ssl_verify_peer]
      #   @socket.post_connection_check(@data[:host])
      # end

      @socket
    end

    private

    def connect
      # backwards compatability for things lacking nonblock
      @nonblock = HAVE_NONBLOCK && @nonblock
      super
    end

  end
end
