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
    end
  end
end
