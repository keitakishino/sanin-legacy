class Trade < ApplicationRecord
  enum :contact, {
    line: 0,
    x: 1,
    discord: 2,
    other_tool: 9
  }

  enum :residue, {
    return: 0,
    cash: 1,
    change: 2,
    other_way: 9
  }
end
