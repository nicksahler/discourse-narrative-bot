# name: discourse-narrative-bot
# about: Introduces staff to Discourse
# version: 0.0.1
# authors: Nick Sahler (@nicksahler)

require 'json'

enabled_site_setting :introbot_enabled

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins", "discourse-narrative-bot", "db", "fixtures").to_s

  require_dependency 'application_controller'
  require_dependency 'discourse_event'
  require_dependency 'admin_constraint'
  require_dependency File.expand_path('../jobs/narrative_input.rb', __FILE__)


  load File.expand_path("../app/models/group_user.rb", __FILE__)
  load File.expand_path("../lib/discourse_narrative_bot/narrative.rb", __FILE__)

  module ::DiscourseNarrativeBot
    PLUGIN_NAME = "discourse-narrative-bot".freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseNarrativeBot
    end

    class Store
      def self.set(user_id, value)
        ::PluginStore.set(PLUGIN_NAME, key(user_id), value)
      end

      def self.get(user_id)
        ::PluginStore.get(PLUGIN_NAME, key(user_id))
      end

      private

      def self.key(user_id)
        "narrative_state_#{user_id}"
      end
    end
  end

  DiscourseNarrativeBot::Engine.routes.draw do
    get "/reset/:user_id/:narrative" => "narratives#reset", constraints: AdminConstraint.new
    get "/status/:user_id/:narrative" => "narratives#status", constraints: AdminConstraint.new
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseNarrativeBot::Engine, at: "/narratives"
  end

  DiscourseEvent.on(:group_user_created) do |group_user|
    user = group_user.user

    if ![-1, -2].include?(user.id)
      if category = Category.find_by(SiteSetting.discobot_category_id)
        category_secure_group_ids = category.secure_group_ids
        group = group_user.group
        user_group_ids = user.group_ids - [group.id]

        if (category.secure_group_ids & user_group_ids).empty? &&
           !(category.secure_group_ids & [group.id]).empty?

          Jobs.enqueue(:narrative_input,
            user_id: user.id,
            input: :init
          )
        end
      end
    end
  end

  DiscourseEvent.on(:post_created) do |post|
    if ![-1, -2].include?(post.user.id)
      Jobs.enqueue(:narrative_input,
        user_id: post.user.id,
        post_id: post.id,
        input: :reply
      )
    end
  end
end
