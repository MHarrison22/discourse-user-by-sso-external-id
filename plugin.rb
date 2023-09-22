# name: discourse-user-by-ss-external-id
# about: Supports linking to user pages by their user id instead of just username
# version: 1.0
# authors: Wilson29thID <wilson@29th.org>
# url: https://github.com/MHarrison22/discourse-user-by-sso-external-id
require 'net/http'
require 'json'


enabled_site_setting :user_by_id_enabled
PLUGIN_NAME ||= 'discourse_user_by_id'.freeze

after_initialize do
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
      raise Discourse::NotFound if params[:path] !~ /^[a-z_\-\/]+$/
		uri = URI('#{:website}/u/by-external/#{params[:id]}.json')
		req = Net::HTTP::Get.new(uri)
		req['Api-Key'] = '#{:api_key}'
		req['Api-Username'] = 'system'
		res = Net::HTTP.start(uri.hostname, uri.port) 
        response = http.request(req)
		obj = JSON.parse(response.body)
		objId = obj['user']['id']
      user = User.find_by(id: objId)
      raise Discourse::NotFound unless user

      guardian.ensure_can_see!(user)

      redirect_to(path("/u/#{user.encoded_username}/#{params[:path]}"))

    end
  end

  DiscourseUserById::Engine.routes.draw do
    get "/:id/*path" => "users#show_by_id", constraints: { id: /\d+/ }
  end

  ::Discourse::Application.routes.append do
    mount ::DiscourseUserById::Engine, at: "/user-by-id"
  end
end
