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

        #logger.info( "initialize:" + (@envoy_installer_session_id).to_str )

      end

      def set_current_grid_profile(name:)
        response = http.put(set_grid_profile_url, json: { selected_profile: name })
        response.raise_for_status
      end

      def get_refreshed_token()
        #From: https://enphase.com/download/accessing-iq-gateway-local-apis-or-local-ui-token-based-authentication
        logger.info('get_refreshed_token')

        #response = httpTokenRefreshLogin.post(
        #  'https://enlighten.enphaseenergy.com/login/login.json?',
        #  form: { 'user[email]': envoy_installer_username, 'user[password]': envoy_installer_password }
        #  )


        response = httpTokenRefreshLogin.post(
          'https://entrez.enphaseenergy.com/login',
          form: { 'username': envoy_installer_username, 'password': envoy_installer_password }
          )

        #logger.info('Response')
        #logger.info(response.body.to_json)
        #logger.info('YYYYYYY')


        #temp = JSON.parse(response)
        #logger.info( temp['session_id'] )


        #responseTokens = httpTokenRefreshLogin.post(
        #  'https://entrez.enphaseenergy.com/tokens',
        #  json: {'session_id': temp['session_id'], 'serial_num': envoy_serial_number, 'username':envoy_installer_username}
        #  )

        #logger.info('ResponseTokens:')
        #logger.info(responseTokens.body.to_json)

        #@envoy_installer_session_id = responseTokens.to_str

        #logger.info( @envoy_installer_session_id )





        #Weird - regular tokens don't give you access to the set_profile commands.... Had to go and get it another way!!!!!!
        responseTokensOther = httpTokenRefresh.post(
          'https://entrez.enphaseenergy.com/entrez_tokens',
          form: {'uncommissioned':'on', 'Site':"", 'serialNum':envoy_serial_number}
          )

        #logger.info('ResponseTokensOther:')
        document = Nokogiri::HTML(responseTokensOther.body.to_s)
        @envoy_installer_session_id = document.at('textarea').text
        #logger.info( @envoy_installer_session_id )



        responseCheckJWT = httpCheckJWT.post(
          "#{base_url}/auth/check_jwt"
        )
        #logger.info('responseCheckJWT:')
        #logger.info(responseCheckJWT.body.to_json)
        #logger.info( responseCheckJWT.headers.to_s )
        #logger.info( responseCheckJWT.headers["set-cookie"] )
        #logger.info( httpCheckJWT.cookies.to_s )


        response.raise_for_status
      end

      #Is this called?
      def installer_home
        response =  http.get(installer_home_url)
        response.raise_for_status
      end

      private

      attr_reader :logger, :envoy_ip, :envoy_serial_number, :envoy_installer_username, :envoy_installer_password

      def httpTokenRefreshLogin
        @httpTokenRefreshLoghin ||=
          HTTPX
            .with(ssl: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
            .plugin(:cookies)
            #.with(debug: STDERR, debug_level: 2)
      end

      def httpTokenRefresh
        @httpTokenRefresh ||=
          HTTPX
            .with(ssl: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
            .plugin(:cookies)
            .with_cookies(httpTokenRefreshLogin.cookies)
            #.with(debug: STDERR, debug_level: 2)
      end

      def httpCheckJWT()
        #logger.info( "httpCheckJWT(...@):" + @envoy_installer_session_id )

        @httpCheckJWT ||=
          HTTPX
            .with_headers('Accept' => 'application/json')
            .plugin(:authentication)
            .authentication("Bearer #{@envoy_installer_session_id}")
            .plugin(:cookies)
            .plugin(:persistent)
            .with(ssl: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
            #.with(debug: STDERR, debug_level: 2)
      end

      def http()
        #logger.info( "http(...@):" + @envoy_installer_session_id )

        @http ||=
          HTTPX
            .with_headers('Accept' => 'application/json')
            .plugin(:authentication)
            .authentication("Bearer #{@envoy_installer_session_id}")
            .plugin(:cookies)
            .with_cookies(httpCheckJWT.cookies)
            .plugin(:persistent)
            .with(ssl: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
            #.with(debug: STDERR, debug_level: 2)
      end

      def set_grid_profile_url
        "#{base_url}/installer/agf/set_profile.json"
      end

      def installer_home_url
        "#{base_url}/installer/setup/home"
      end

      def base_url
        "https://#{envoy_ip}"
      end
    end
  end
end
