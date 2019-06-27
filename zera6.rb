require 'set'
require 'contracts'

C = Contracts

module Zera6
  class Database
    include Contracts::Core

    attr_reader :t

    BASE_SCHEMA = [
      {'zera/id': :'zera/id'},
      {'zera/id': :'zera/cardinality', 'zera/type': :'zera.type/ref'},
      {'zera/id': :'zera.cardinality/one'},
      {'zera/id': :'zera.cardinality/many'},
      {'zera/id': :'zera/type', 'zera/type': :'zera.type/ref'},
      {'zera/id': :'zera.type/string'},
      {'zera/id': :'zera.type/boolean'},
      {'zera/id': :'zera.type/float'},
      {'zera/id': :'zera.type/integer'},
      {'zera/id': :'zera.type/keyword'},
      {'zera/id': :'zera.type/ref'},
      {'zera/id': :'zera/doc', 'zera/type': :'zera.type/string'},
      {'zera/id': :'zera/component?', 'zera/type': :'zera.type/boolean'},
    ]

    def self.init
      db = new
      db.assert(BASE_SCHEMA)
      db
    end

    def initialize
      @eavt = {}
      @aevt = {}
      @avet = {}
      @vaet = {}
      @t = 0
    end

    def tick!
      @t += 1
    end

    Contract C::ArrayOf[C::Or[Hash, Array]] => Database
    def assert(facts)
      tick!
      facts.each do |fact|
        if fact.is_a?(Hash)
          assert_hash(fact)
        else
          e, a, v = fact
          fact = if v.is_a?(Hash)
                   ref = assert_hash(v)
                   [e, a, ref]
                 else
                   fact
                 end
          index_eavt(fact)
          index_aevt(fact)
          index_avet(fact)
          index_vaet(fact)
        end
      end
      self
    end

    Contract C::ArrayOf[Array] => Database
    def retract(facts)
      tick!
      @facts[@t] = facts.map { |f| [:retraction] + f }
      facts.each do |fact|
        index_eavt(fact, false)
        index_aevt(fact, false)
        index_avet(fact, false)
        index_vaet(fact, false)
      end
      self
    end

    def lookup(pattern, asof = t)
      if pattern.is_a?(Array) and pattern.length == 3
        e, a, v = pattern
        if var?(e) and var?(a) and var?(v)
          []
        elsif var?(e) and var?(a)
          v_lookup(v, asof)
        elsif var?(e) and var?(v)
          a_lookup(a, asof)
        elsif var?(a) and var?(v)
          e_lookup(e, asof)
        elsif var?(e)
          av_lookup(a, v, asof)
        elsif var?(a)
          ev_lookup(e, v, asof)
        elsif var?(v)
          ea_lookup(e, a, asof)
        else
          eav_lookup(e, a, v, asof)
        end
      else
        raise "Don't know how to find a value based on the given pattern: #{pattern.inspect}"
      end
    end

    Contract C::ArrayOf[Array] => C::Any
    def pull(form, asof = t)
      i = -1
      var_indexes = form.flat_map { |x| x.select(&method(:var?)) }
                        .reduce({}) { |h, var| h[var] ? h : h.merge!(var => i += 1) }
      p form.map { |x| x.select(&method(:var?)).map { |v| var_indexes[v] } }
      form.map(&method(:lookup)).reduce(Set.new) do |s, res|

      end
    end

    def entity(eid, asof = t)
      e_lookup(eid, asof).reduce({}) do |h, (attr, value)|
        if (v = h[attr])
          if v.is_a?(Set)
            h.merge!(attr => v + [value])
          else
            h.merge!(attr => Set[v, value])
          end
        else
          h.merge!(attr => value)
        end
      end
    end

    private

    def assert_hash(hash, eid = hash[:'zera/id'] || hash.object_id)
      facts = hash.map do |(attr, value)|
        [eid, attr, value]
      end
      assert(facts)
      eid
    end

    def var?(x)
      x.is_a?(Symbol) and x.to_s.end_with?('?')
    end

    def v_lookup(v, asof)
      idx = @vaet[v]
      if idx.nil?
        nil
      else
        idx.flat_map do |(attr, xs)|
          xs.select { |_e, t| t.keys.first <= asof }.map { |x| [attr, x[0]] }
        end.to_set
      end
    end

    def e_lookup(e, asof)
      idx = @eavt[e]
      if idx.nil?
        nil
      else
        idx.flat_map do |(attr, xs)|
          xs.select { |_v, t| t.keys.first <= asof }.map { |x| [attr, x[0]] }
        end.to_set
      end
    end

    def a_lookup(a, asof)
      idx = @aevt[a]
      if idx.nil?
        nil
      else
        idx.flat_map do |(e, xs)|
          xs.select { |_v, t| t.keys.first <= asof }.map { |x| [e, x[0]] }
        end.to_set
      end
    end

    def av_lookup(a, v, asof)
      x = @avet.dig(a, v)
      if x.nil?
        nil
      else
        x.select { |_e, t| t.keys.first <= asof }
         .map { |x| [x[0]] }.to_set
      end
    end

    def ev_lookup(e, v, asof)
      idx = @eavt[e]
      if idx.nil?
        nil
      else
        idx.map do |(attr, xs)|
          if (x = xs[v]).nil?
            nil
          else
            if x.any? { |t, _| t <= asof }
              Set[attr]
            else
              nil
            end
          end
        end.reject(&:nil?).to_set
      end
    end

    def ea_lookup(e, a, asof)
      idx = @eavt.dig(e, a)
      if idx.nil?
        nil
      else
        idx.select { |_v, t| t.keys.first <= asof }
          .map { |x| [x[0]] }
          .to_set
      end
    end

    def eav_lookup(e, a, v, asof)
      idx = @eavt.dig(e, a, v)
      if idx.nil?
        nil
      else
        idx.keys.first <= asof
      end
    end

    def index_eavt(fact, op = true)
      e, a, v = fact
      if not @eavt.key?(e)
        @eavt[e] = { a => { v => { @t => op } } }
      elsif not @eavt[e].key?(a)
        @eavt[e][a] = { v => { @t => op } }
      elsif not @eavt[e][a].key?(v)
        @eavt[e][a][v] = { @t => op }
      elsif not @eavt[e][a][v].key?(@t)
        @eavt[e][a][v][@t] = op
      else
        raise 'Unknown error indexing EAVT'
      end
    end

    def index_aevt(fact, op = true)
      e, a, v = fact
      if not @aevt.key?(a)
        @aevt[a] = { e => { v => { @t => op } } }
      elsif not @aevt[a].key?(e)
        @aevt[a][e] = { v => { @t => op } }
      elsif not @aevt[a][e].key?(v)
        @aevt[a][e][v] = { @t => op }
      elsif not @aevt[a][e][v].key?(@t)
        @aevt[a][e][v][@t] = op
      else
        raise 'Unknown error indexing EAVT'
      end
    end

    def index_avet(fact, op = true)
      e, a, v = fact
      if not @avet.key?(a)
        @avet[a] = { v => { e => { @t => op } } }
      elsif not @avet[a].key?(v)
        @avet[a][v] = { e => { @t => op } }
      elsif not @avet[a][v].key?(e)
        @avet[a][v][e] = { @t => op }
      elsif not @avet[a][v][e].key?(@t)
        @avet[a][v][e][@t] = true
      else
        raise 'Unknown error indexing EAVT'
      end
    end

    def index_vaet(fact, op = true)
      e, a, v = fact
      if not @vaet.key?(v)
        @vaet[v] = { a => { e => { @t => op } } }
      elsif not @vaet[v].key?(a)
        @vaet[v][a] = { e => { @t => op } }
      elsif not @vaet[v][a].key?(e)
        @vaet[v][a][e] = { @t => op }
      elsif not @vaet[v][a][e].key?(@t)
        @vaet[v][a][e][@t] = op
      else
        raise 'Unknown error indexing EAVT'
      end
    end
  end

  module Lang
    DB = Zera6::Database.init
    
    def self.eval(form)
      case form
      when String, Float, Symbol
        form
      when Array
        case form[0]
        when :assert
          DB.assert(form.drop(1))
        else
          raise "Not implemented"
        end
      else
        raise "Unknown form: #{form.inspect}"
      end
    end
  end
end

Zera6::Lang.eval(
  [:assert,
   {'zera/id': :'zera.string/value',
    'zera/type': :'zera.type/string'},

   {'zera/id': :'zera.integer/value',
    'zera/type': :'zera.type/integer'},

   {'zera/id': :'zera.float/value',
    'zera/type': :'zera.type/float'},

   {'zera/id': :'zera.symbol/name',
    'zera/type': :'zera.type/string'},
   {'zera/id': :'zera.symbol/namespace',
    'zera/type': :'zera.type/string'},
   {'zera/id': :'zera.symbol/value',
    'zera/type': :'zera.type/ref'},

   {'zera/id': :'zera.cons/car',
    'zera/type': :'zera.type/ref'},
   {'zera/id': :'zera.cons/cdr',
    'zera/type': :'zera.type/ref'},

   {'zera.cons/car': {'zera.integer/value': 1},
    'zera.cons/cdr': {'zera.cons/car': 0}},
])
