require_relative 'rust/core'
require_relative 'rust/models/all'
require_relative 'rust/plots/all'
require_relative 'rust/stats/all'

module Rust
    @@datasets = {}
    
    def self.toothgrowth
        @@datasets[:ToothGrowth] = Rust.exclusive { Rust['ToothGrowth'] } unless @@datasets[:ToothGrowth]
        return @@datasets[:ToothGrowth]
    end
    
    def self.cars
        @@datasets[:cars] = Rust.exclusive { Rust['cars'] } unless @@datasets[:cars]
        return @@datasets[:cars]
    end
    
    def self.iris
        @@datasets[:iris] = Rust.exclusive { Rust['iris'] } unless @@datasets[:iris]
        return @@datasets[:iris]
    end
end
