# frozen_string_literal: true

module Abacus
  # То же, что ActiveSupport::Concern, написанное своими руками.
  #
  # Решает две задачи, которые в s01e09 пришлось решать вручную:
  #   1. ClassMethods подключается сам;
  #   2. зависимости между примесями разворачиваются в правильном порядке.
  module Concern
    class MultipleIncludedBlocks < StandardError
      def initialize(message = "у примеси может быть только один блок included")
        super
      end
    end

    # Каждая примесь заводит себе список отложенных зависимостей.
    # Именно наличие этой переменной отличает примесь от обычного класса —
    # на этом построен весь приём.
    def self.extended(base)
      base.instance_variable_set(:@_dependencies, [])
    end

    # append_features — то, что Ruby зовёт при include. Перехватив его,
    # мы решаем, включаться сейчас или подождать.
    def append_features(base)
      if base.instance_variable_defined?(:@_dependencies)
        # Нас включают в другую примесь. Значит, рано: запоминаемся у неё
        # и не включаемся вовсе (false говорит Ruby «ничего не делал»).
        base.instance_variable_get(:@_dependencies) << self
        false
      else
        # Нас включают в настоящий класс.
        return false if base < self # уже включены — второй раз не нужно

        # Сначала все, от кого мы зависим, — и прямо в этот класс,
        # а не в себя. Порядок в цепочке предков получается верный.
        @_dependencies.each { |dependency| base.include(dependency) }
        super
        base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
        base.class_eval(&@_included_block) if instance_variable_defined?(:@_included_block)
      end
    end

    # Два метода в одном: с аргументом — обычный хук Ruby, без аргумента —
    # объявление блока, который выполнится в классе-хозяине.
    def included(base = nil, &block)
      if base.nil?
        raise MultipleIncludedBlocks if instance_variable_defined?(:@_included_block)

        @_included_block = block
      else
        super
      end
    end

    # Сахар: ClassMethods без ручного объявления вложенного модуля.
    def class_methods(&block)
      mod = if const_defined?(:ClassMethods, false)
              const_get(:ClassMethods)
            else
              const_set(:ClassMethods, Module.new)
            end

      mod.module_eval(&block)
    end
  end
end
