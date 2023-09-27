# frozen_string_literal: true

require 'httpx'

require 'nokogiri'

module Zest
  module Enphase
    class Client
      def initialize(logger:, envoy_ip:, envoy_serial_number:, envoy_installer_username:, envoy_installer_password:)
        @logger = logger
        @envoy_ip = envoy_ip
        @envoy_serial_number = envoy_serial_number
        @envoy_installer_username = envoy_installer_username
        @envoy_installer_password = envoy_installer_password
        @envoy_installer_session_id = nil
        self.get_refreshed_token()
      end

      def set_current_grid_profile(name:)
        response = http.put(set_grid_profile_url, json: { selected_profile: name })
        response.raise_for_status
      end

      def get_refreshed_token()
        #Initially this followed the Enphase documentation:
        #From: https://enphase.com/download/accessing-iq-gateway-local-apis-or-local-ui-token-based-authentication
        # but tokens created that way are missing "something" (they don't work for set_profile....)

        response = httpTokenRefresh.post(
          'https://entrez.enphaseenergy.com/login',
          form: { 'username': envoy_installer_username, 'password': envoy_installer_password }
          )

        #Weird - regular tokens don't give you access to the set_profile commands.... Had to go and get it another way!!!!!!
        responseTokens = httpTokenRefresh.post(
          'https://entrez.enphaseenergy.com/entrez_tokens',
          form: {'uncommissioned':'on', 'Site':"", 'serialNum':envoy_serial_number}
          )
        #This is the text area containing the copy-and-paste code from the Entrez UI
        document = Nokogiri::HTML(responseTokens.body.to_s)
        @envoy_installer_session_id = document.at('textarea').text

        #Return the login attempt -- more likely to be a credential issue
        response.raise_for_status
      end

      private

      attr_reader :logger, :envoy_ip, :envoy_serial_number, :envoy_installer_username, :envoy_installer_password

      def httpTokenRefresh
        @httpTokenRefresh ||=
          HTTPX
            .with(ssl: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
            .plugin(:cookies)
            #.with(debug: STDERR, debug_level: 2)
      end

      def http()
        @http ||=
          HTTPX
            .with_headers('Accept' => 'application/json')
            .plugin(:authentication)
            .authentication("Bearer #{@envoy_installer_session_id}")
            .plugin(:persistent)
            .with(ssl: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
            #.with(debug: STDERR, debug_level: 2)
      end

      def set_grid_profile_url
        "#{base_url}/installer/agf/set_profile.json"
      end

      def base_url
        "https://#{envoy_ip}"
      end
    end
  end
end
