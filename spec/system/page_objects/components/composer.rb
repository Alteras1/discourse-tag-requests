# frozen_string_literal: true

module PageObjects
  module Components
    class Composer < PageObjects::Components::Base
      def request_tag(name)
        tag_chooser = PageObjects::Components::SelectKit.new("#reply-control .mini-tag-chooser")
        tag_chooser.expand
        tag_chooser.search(name)
        tag_chooser.select_row_by_value(name)
        tag_chooser.collapse
      end
    end
  end
end
