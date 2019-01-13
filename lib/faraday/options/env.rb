module Faraday
  # @!attribute method
  #   @return [Symbol] HTTP method (`:get`, `:post`)
  #
  # @!attribute body
  #   @return [String] The request body that will eventually be converted to a string.
  #
  # @!attribute url
  #   @return [URI] URI instance for the current request.
  #
  # @!attribute request
  #   @return [Hash] options for configuring the request.
  #   Options for configuring the request.
  #
  #   - `:timeout`  open/read timeout Integer in seconds
  #   - `:open_timeout` - read timeout Integer in seconds
  #   - `:on_data`      - Proc for streaming
  #   - `:proxy`        - Hash of proxy options
  #       - `:uri`        - Proxy Server URI
  #       - `:user`       - Proxy server username
  #       - `:password`   - Proxy server password
  #
  # @!attribute request_headers
  #   @return [Hash] HTTP Headers to be sent to the server.
  #
  # @!attribute ssl
  #   @return [Hash] options for configuring SSL requests
  #
  # @!attribute parallel_manager
  #   @return [Object] sent if the connection is in parallel mode
  #
  # @!attribute params
  #   @return [Hash]
  #
  # @!attribute response
  #   @return [Response]
  #
  # @!attribute response_headers
  #   @return [Hash] HTTP headers from the server
  #
  # @!attribute status
  #   @return [Integer] HTTP response status code
  #
  # @!attribute reason_phrase
  #   @return [String]
  class Env < Options.new(:method, :body, :url, :request, :request_headers,
                          :ssl, :parallel_manager, :params, :response, :response_headers, :status,
                          :reason_phrase)

    ContentLength = 'Content-Length'.freeze
    StatusesWithoutBody = Set.new [204, 304]
    SuccessfulStatuses = 200..299

    # A Set of HTTP verbs that typically send a body.  If no body is set for
    # these requests, the Content-Length header is set to 0.
    MethodsWithBodies = Set.new [:post, :put, :patch, :options]

    options :request => RequestOptions,
            :request_headers => Utils::Headers, :response_headers => Utils::Headers

    extend Forwardable

    def_delegators :request, :params_encoder

    # Build a new Env from given value. Respects and updates `custom_members`.
    #
    # @param value [Object] a value fitting Option.from(v).
    # @return [Env] from given value
    def self.from(value)
      env = super(value)
      if value.respond_to?(:custom_members)
        env.custom_members.update(value.custom_members)
      end
      env
    end

    # @param key [Object]
    def [](key)
      if in_member_set?(key)
        super(key)
      else
        custom_members[key]
      end
    end

    # @param key [Object]
    # @param value [Object]
    def []=(key, value)
      if in_member_set?(key)
        super(key, value)
      else
        custom_members[key] = value
      end
    end

    # @return [Boolean] true if status is in the set of {SuccessfulStatuses}.
    def success?
      SuccessfulStatuses.include?(status)
    end

    # @return [Boolean] true if there's no body yet, and the method is in the set of {MethodsWithBodies}.
    def needs_body?
      !body && MethodsWithBodies.include?(method)
    end

    # Sets content length to zero and the body to the empty string.
    def clear_body
      request_headers[ContentLength] = '0'
      self.body = ''
    end

    # @return [Boolean] true if the status isn't in the set of {StatusesWithoutBody}.
    def parse_body?
      !StatusesWithoutBody.include?(status)
    end

    # @return [Boolean] true if there is a parallel_manager
    def parallel?
      !!parallel_manager
    end

    def inspect
      attrs = [nil]
      members.each do |mem|
        if value = send(mem)
          attrs << "@#{mem}=#{value.inspect}"
        end
      end
      if !custom_members.empty?
        attrs << "@custom=#{custom_members.inspect}"
      end
      %(#<#{self.class}#{attrs.join(" ")}>)
    end

    # @private
    def custom_members
      @custom_members ||= {}
    end

    # @private
    if members.first.is_a?(Symbol)
      def in_member_set?(key)
        self.class.member_set.include?(key.to_sym)
      end
    else
      def in_member_set?(key)
        self.class.member_set.include?(key.to_s)
      end
    end

    # @private
    def self.member_set
      @member_set ||= Set.new(members)
    end
  end
end