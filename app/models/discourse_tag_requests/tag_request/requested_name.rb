# frozen_string_literal: true

module DiscourseTagRequests
  # A requested name keeps its casing, but `id` identifies it case-insensitively
  # so service locks treat "Rust" and "rust" as the same request.
  TagRequest::RequestedName =
    Data.define(:name) do
      def id
        name.downcase
      end
    end
end
