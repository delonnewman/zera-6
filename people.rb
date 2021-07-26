require_relative 'zera6'

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

#DB.assert(Cons.list(1, 2, 3, 4, 5))

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
