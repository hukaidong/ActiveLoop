# frozen_string_literal: true

require 'active_record'
require_relative './parameter_object'
module ParameterObjectRelationActions
  def initialize_database(force: false)
    connection.create_table :parameter_relations, force: force do |t|
      t.belongs_to :from, class_name: 'ParameterObject'
      t.belongs_to :to, class_name: 'ParameterObject'
      t.string :relation, default: 'relation_nil'
    end
  end
end
class ParameterObjectRelation < ActiveRecord::Base
  self.table_name = 'parameter_relations'

  ALL_RELATION = %w[relation_nil prediction augmentation].freeze
  enum relation: ALL_RELATION.zip(ALL_RELATION).to_h
  belongs_to :from, class_name: 'ParameterObject'
  belongs_to :to, class_name: 'ParameterObject'

  extend ParameterObjectRelationActions
end