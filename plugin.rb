# name: discourse-user-by-sso-external-id
# about: Supports linking to user pages by their user id instead of just username
# version: 1.0
# authors: Wilson29thID <wilson@29th.org>
# url: https://github.com/MHarrison22/discourse-user-by-sso-external-id
require 'net/http'
require 'json'


enabled_site_setting :user_by_external_sso_enabled
PLUGIN_NAME ||= 'discourse_user_by_sso_external_id'.freeze

after_initialize do
puts "miles-plugin-init"
puts "externalsso web #{SiteSetting.user_by_external_sso_website}"
puts "externalsso api #{SiteSetting.user_by_external_sso_api_key}"

  module ::DiscourseUserById
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseUserById
    end
  end

  class DiscourseUserById::UsersController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :check_xhr, only: [:show_by_id]
    after_action :add_noindex_header, only: [:show_by_id]

    def show_by_id
			puts "website-miles #{SiteSetting.user_by_external_sso_website} | apikey #{SiteSetting.user_by_external_sso_api_key}"
      #raise Discourse::NotFound if params[:path] !~ /^[a-z_\-\/]+$/
	  puts "uriparser #{SiteSetting.user_by_external_sso_website}/u/by-external/#{params[:id]}.json" 
		uri = URI.parse("#{SiteSetting.user_by_external_sso_website}/u/by-external/#{params[:id]}.json")
		req = Net::HTTP::Get.new(uri)
		puts "afterurireq"

		req['Api-Key'] = "#{SiteSetting.user_by_external_sso_api_key}"
		req['Api-Username'] = "system"
                req_options = {
                  use_ssl: uri.scheme == 'https'
                }
				puts "test123"
		res = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
                  response = http.request(req)
				  puts "test234"
                  responseForceEnc = response.body.force_encoding('UTF-8') 
                  obj = JSON.parse(responseForceEnc)
				  puts "#{responseForceEnc}"
                  objId = obj['user']['id']
				  puts "website-miles-obj-id #{objId}"
                  user = User.find_by(id: objId)
      raise Discourse::NotFound unless user

      guardian.ensure_can_see!(user)

      redirect_to(path("/u/#{user.username}/#{params[:path]}"))
                end

    end
  end

  DiscourseUserById::Engine.routes.draw do
    get "/:id/*path" => "users#show_by_id"
  end

  ::Discourse::Application.routes.append do
    mount ::DiscourseUserById::Engine, at: "/user-by-id"
  end
end
