require 'set'

module Zera6
  class Object
  end

  class Cons < Object
    include Enumerable

    attr_reader :car, :cdr
  
    def self.list(*args)
      xs = nil
      x = args.last
      while not x.nil?
        xs = Cons.new(x, xs)
        args = args.slice(0, args.length - 1)
        x = args.last
      end
      xs
    end

    def initialize(car, cdr)
      @car, @cdr = car, cdr
    end
  
    def facts
      if cdr.nil?
        [[object_id, :car, car], [object_id, :cdr, cdr]]
      else
        [[object_id, :car, car], [object_id, :cdr, cdr.object_id]] + cdr.facts
      end
    end

    def each
      if cdr.nil?
        yield car
      else
        x = car
        xs = cdr
        while not xs.nil?
          yield x
          x = xs.car
          xs = xs.cdr
        end
      end
      self
    end

    def to_s
      "(#{map(&:to_s).join(' ')})"
    end
  end

  class Database
    attr_reader :t

    def initialize
      @eavt = {}
      @aevt = {}
      @avet = {}
      @vaet = {}
      @facts = {}
      @t = 0
    end

    def tick!
      @t += 1
    end

    def assert(facts)
      if facts.is_a?(Hash)
        assert_hash(facts)
      elsif facts.respond_to?(:facts)
        assert(facts.facts)
      else
        tick!
        @facts[@t] = facts.map { |f| [:assertion] + f }
        facts.each do |fact|
          index_eavt(fact)
          index_aevt(fact)
          index_avet(fact)
          index_vaet(fact)
        end
      end
    end

    def retract(facts)
      tick!
      @facts[@t] = facts.map { |f| [:retraction] + f }
      facts.each do |fact|
        index_eavt(fact, false)
        index_aevt(fact, false)
        index_avet(fact, false)
        index_vaet(fact, false)
      end
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

    def assert_hash(hash, eid = hash[:'db/id'] || hash.object_id)
      facts = hash.map do |(attr, value)|
        [eid, attr, value]
      end
      assert(facts)
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
        end
      end
    end

    def e_lookup(e, asof)
      idx = @eavt[e]
      if idx.nil?
        nil
      else
        idx.flat_map do |(attr, xs)|
          xs.select { |_v, t| t.keys.first <= asof }.map { |x| [attr, x[0]] }
        end
      end
    end

    def a_lookup(a, asof)
      idx = @aevt[a]
      if idx.nil?
        []
      else
        idx.flat_map do |(e, xs)|
          xs.select { |_v, t| t.keys.first <= asof }.map { |x| [e, x[0]] }
        end
      end
    end

    def av_lookup(a, v, asof)
      x = @avet.dig(a, v)
      if x.nil?
        nil
      else
        x.select { |_e, t| t.keys.first <= asof }
         .map { |x| [x[0]] }
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
              [attr]
            else
              nil
            end
          end
        end.reject(&:nil?)
      end
    end

    def ea_lookup(e, a, asof)
      idx = @eavt.dig(e, a)
      if idx.nil?
        nil
      else
        idx.select { |_v, t| t.keys.first <= asof }
           .map { |x| [x[0]] }
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
end

include Zera6

DB = Database.new

DB.assert([[:jackie, :name, "Jackie Newman"],
           [:jackie, :super_hero_name, "Luna"],
           [:jackie, :likes, :jazz],
           [:jackie, :likes, :delon],
           [:jackie, :likes, :red],
           [:jackie, :likes, :coffee],
           [:jackie, :loves, :jehovah],
           [:jackie, :loves, :delon]])

DB.assert([[:delon, :likes, :jazz],
           [:delon, :likes, :jackie],
           [:delon, :loves, :jehovah],
           [:delon, :loves, :jackie]])

DB.assert({'db/id': :kalob,
           name: 'Kalob',
           age: 14,
           likes: :pizza,
           loves: :jehovah,
           rapper_name: "Lil-Putt-Putt",
           super_hero_name: "K-Man",
           secondary_rapper_name: "Young Kay"})

DB.assert([[:jackie, :likes, :jazz]])
DB.assert([[:jackie, :likes, :hot_coffee]])
DB.retract([[:jackie, :likes, :coffee]])

DB.assert([[:jackie, :married, :delon]])
DB.assert([[:jackie, :wife_of, :delon]])
DB.assert([[:delon, :husband_of, :jackie]])

DB.assert([[:anna, :mother_of, :jackie], [:anna, :mother_of, :mike], [:skye, :mother_of, :delon], [:skye, :mother_of, :devin]])
DB.assert([[:marion, :mother_of, :skye], [:marion, :mother_of, :robin]])
DB.assert([[:skye, :sex, :female]])
DB.assert({'db/id': :robin, name: 'Robin', age: 29, likes: :icecream, loves: :jehovah, mother_of: :kalob, sex: :female})

DB.assert([[:devin, :sex, :male], [:delon, :sex, :male]])

DB.assert(Cons.list(1, 2, 3, 4, 5))

p DB.lookup([:who?, :likes, :jazz])
p DB.lookup([:who?, :likes, :what?])
p DB.lookup([:who?, :does?, :jazz])
p DB.lookup([:who?, :does?, :what?])
p DB.lookup([:jackie, :likes, :jazz])
p DB.lookup([:jackie, :likes, :cold_food])
p DB.lookup([:e?, :name, "Kalob"])
p DB.lookup([:jackie, :does?, :what?])
p DB.entity(:jackie)
p DB.lookup([:jackie, :does?, :delon])
p DB.lookup([:jackie, :loves, :what?])
p DB.lookup([:who?, :loves, :jehovah])

def siblings?(a, b)
  DB.lookup([:e?, :mother_of, a]) == DB.lookup([:e?, :mother_of, b])
end

def brothers?(a, b)
  siblings?(a, b) and DB.lookup([a, :sex, :male]) and DB.lookup([b, :sex, :male])
end

def sisters?(a, b)
  siblings?(a, b) and DB.lookup([a, :sex, :male]) and DB.lookup([b, :sex, :female])
end
