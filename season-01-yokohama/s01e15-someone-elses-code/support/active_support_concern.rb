# frozen_string_literal: true
#
# ЧТЕНИЕ К СЕРИИ s01e15 — не запускается, не проверяется, менять не нужно.
#
# Это ActiveSupport::Concern из Rails (MIT), приведённый к одному файлу:
# убраны ветки prepend и часть проверок, чтобы читать можно было подряд.
# Оригинал: rails/activesupport/lib/active_support/concern.rb
#
# Copyright (c) David Heinemeier Hansson, MIT License.
#
# Задача серии — объяснить здесь каждую строку, а потом написать своё.

module ActiveSupport
  module Concern
    class MultipleIncludedBlocks < StandardError
      def initialize
        super "Cannot define multiple 'included' blocks for a Concern"
      end
    end

    def self.extended(base)
      base.instance_variable_set(:@_dependencies, [])
    end

    def append_features(base)
      if base.instance_variable_defined?(:@_dependencies)
        base.instance_variable_get(:@_dependencies) << self
        false
      else
        return false if base < self

        @_dependencies.each { |dep| base.include(dep) }
        super
        base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
        base.class_eval(&@_included_block) if instance_variable_defined?(:@_included_block)
      end
    end

    def included(base = nil, &block)
      if base.nil?
        if instance_variable_defined?(:@_included_block)
          if @_included_block.source_location != block.source_location
            raise MultipleIncludedBlocks
          end
        else
          @_included_block = block
        end
      else
        super
      end
    end

    def class_methods(&class_methods_module_definition)
      mod = const_defined?(:ClassMethods, false) ?
        const_get(:ClassMethods) :
        const_set(:ClassMethods, Module.new)

      mod.module_eval(&class_methods_module_definition)
    end
  end
end
