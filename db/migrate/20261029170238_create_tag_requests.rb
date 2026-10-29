# frozen_string_literal: true
class CreateTagRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :tag_requests do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.integer :status, null: false, default: 0
      t.bigint :reviewable_id, null: false
      t.timestamps
    end

    add_index :tag_requests, :normalized_name, unique: true
    add_index :tag_requests, :reviewable_id, unique: true

    create_table :tag_request_topics do |t|
      t.bigint :tag_request_id, null: false
      t.integer :topic_id, null: false
      t.integer :requested_by_id, null: false
      t.timestamps
    end

    add_index :tag_request_topics, %i[tag_request_id topic_id], unique: true
    add_index :tag_request_topics, :topic_id
  end
end
