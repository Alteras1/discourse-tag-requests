# frozen_string_literal: true

module PageObjects
  module Pages
    class Topic < PageObjects::Pages::Base
      def has_requested_tag?(name)
        has_css?(".title-wrapper .requested-tag", text: name)
      end

      def has_no_requested_tag?(name)
        has_no_css?(".title-wrapper .requested-tag", text: name)
      end

      def edit_requested_tags(request:, withdraw:)
        click_topic_edit_title
        tag_chooser =
          PageObjects::Components::SelectKit.new(".edit-tags__wrapper .mini-tag-chooser")
        find(".edit-tags__wrapper .requested-tag-choice", text: withdraw).click
        tag_chooser.expand
        tag_chooser.search(request)
        tag_chooser.select_row_by_value(request)
        click_topic_title_submit_edit
      end
    end
  end
end
