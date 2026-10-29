# frozen_string_literal: true
class CreateTagSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :tag_suggestions do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.integer :status, null: false, default: 0
      t.bigint :reviewable_id, null: false
      t.timestamps
    end

    add_index :tag_suggestions, :normalized_name, unique: true
    add_index :tag_suggestions, :reviewable_id, unique: true

    create_table :tag_suggestion_topics do |t|
      t.bigint :tag_suggestion_id, null: false
      t.integer :topic_id, null: false
      t.integer :suggested_by_id, null: false
      t.timestamps
    end

    add_index :tag_suggestion_topics, %i[tag_suggestion_id topic_id], unique: true
    add_index :tag_suggestion_topics, :topic_id
  end
end
