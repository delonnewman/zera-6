require 'json'

module Zera6
  class Syntax
    attr_reader :parameters

    def initialize(*args)
      @parameters = args.freeze
    end

    def compile_to(other)
      other.new(*@parameters).to_s
    end
  end

  class Nil < Syntax
    def to_s
      'nil'
    end
  end

  class Boolean < Syntax
    def initialize(value)
      super
      @value = value
    end

    def to_s
      @value ? 'true' : 'false'
    end
  end

  class String < Syntax
    def initialize(value)
      super
      @value = value
    end

    def to_s
      "\"#{value.to_json}\""
    end
  end

  class Number < Syntax
  end

  class List < Syntax
  end

  class Vector < Syntax
  end

  class Map < Syntax
  end

  class Procedure < Syntax
    attr_reader :name, :args, :body

    def initialize(name, args, body)
      super
      @name = name
      @args = args
      @body = body
    end

    def anonymous?
      @name.nil?
    end
  end

  class Quote < Syntax
  end

  class ImperativeBlock < Syntax
  end

  class LexicalScope < Syntax
  end

  class Loop < Syntax
  end
end

module WS
  class Nil < Zera6::Nil
  end

  class Boolean < Zera6::Boolean
  end

  class Symbol < Zera6::String
  end

  class Number < Zera6::String
  end

  class Array < Zera6::Vector
  end

  class Map < Zera6::Map
  end

  class Function < Zera6::Procedure
  end

  class Cond
    attr_reader :predicate, :pairs

    def initialize(predicate, pairs)
      super
      @predicate = predicate
      @pairs = pairs
    end
  end
end

module JS
  class Null < Zera6::Nil
    def to_s
      'null'
    end
  end

  class Undefined < Zera6::Nil
    def to_s
      'undefined'
    end
  end

  class Boolean < Zera6::Boolean
  end

  class Number < Zera6::String
  end

  class String < Zera6::String
  end

  class Array < Zera6::Vector
  end

  class Map < Zera6::Map
  end

  class FunctionExpression < Zera6::Procedure
    def to_s
      last = body.last
      rest = body.slice(0, body.length - 1)
      "(function#{anonymous? ? '' : " #{name}"}(#{args.join(', ')}) { #{rest.empty? ? '' : "#{rest.join(';')};"} return #{last}; })"
    end
  end
end

puts WS::Nil.new.compile_to(JS::Null)
puts WS::Nil.new.compile_to(JS::Undefined)
puts WS::Boolean.new(true).compile_to(JS::Boolean)
puts WS::Function.new('identity', [:x], [:x]).compile_to(JS::FunctionExpression)
