require 'geoip2/api/city'
require 'geoip2/api/city_isp_org'
require 'geoip2/api/country'
require 'geoip2/api/omni'
require 'geoip2/api/insights'
require 'active_support/notifications'
require 'faraday'
require 'typhoeus'
require 'typhoeus/adapters/faraday'
require 'faraday_middleware'

module Geoip2
  class Client

    include Geoip2::Api::City
    include Geoip2::Api::Country
    include Geoip2::Api::CityIspOrg
    include Geoip2::Api::Omni
    include Geoip2::Api::Insights

    #
    # Creates a new instance of Geoip2::Client
    #
    # @param config [Hash] includes all of the config from the
    def initialize(config)
      @base_url = "https://#{config[:host]}"
      @base_path = config[:base_path]
      @parallel_requests = config[:parallel_requests]
      @user = config[:user_id]
      @password = config[:license_key]
    end

    #
    # Does a GET request to the url with the params
    #
    # @param url [String] the relative path in the Geoip2 API
    # @param params [Hash] the url params that should be passed in the request
    def get(url, params = {})
      params = params.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}
      preform(@base_path + url, :get, params: params) do
        return connection.get(@base_path + url, params).body
      end
    end

    #
    # Does a parallel request to the api for all of the requests in the block
    #
    # @example block
    #   Geoip2.in_parallel do
    #     Geoip2.create_review(review_params)
    #     Geoip2.update_account(account_params)
    #   end
    def in_parallel
      connection.in_parallel do
        yield
      end
    end

    private

    #
    # Preforms an HTTP request and notifies the ActiveSupport::Notifications
    #
    # @private
    # @param url [String] the url to which preform the request
    # @param type [String]
    def preform(url, type, params = {}, &block)
      ActiveSupport::Notifications.instrument 'Geoip2', request: type, base_url: url, params: params do
        block.call
      end
    end

    #
    # @return an instance of Faraday initialized with all that this gem needs
    def connection
      @connection ||= Faraday.new(url: @base_url, parallel_manager: Typhoeus::Hydra.new(max_concurrency: @parallel_requests)) do |conn|

        conn.request :basic_auth, @user, @password

        # Set the response to be rashified
        conn.response :rashify

        # Setting request and response to use JSON/XML
        conn.request :json
        conn.response :json

        # Set to use instrumentals to get time logs
        conn.use :instrumentation

        conn.adapter :typhoeus
      end
    end
  end
end
