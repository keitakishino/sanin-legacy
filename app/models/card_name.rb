class CardName < ApplicationRecord
  SUGGESTION_LIMIT = 8

  validates :name, presence: true, uniqueness: true, length: { maximum: 255 }

  scope :suggest, ->(query) do
    query = query.to_s.strip
    return none if query.blank?

    escaped = sanitize_sql_like(query.downcase)
    where("LOWER(name) LIKE ?", "%#{escaped}%")
      .order(
        Arel.sql(
          sanitize_sql_array(
            [
              "CASE WHEN LOWER(name) LIKE ? THEN 0 WHEN LOWER(name) LIKE ? THEN 1 ELSE 2 END",
              "#{escaped}%",
              "% #{escaped}%"
            ]
          )
        ),
        :name
      )
      .limit(SUGGESTION_LIMIT)
  end
end
