module CardDetailListing
  extend ActiveSupport::Concern

  SORT_OPTIONS = %w[card_name_asc card_name_desc quantity_asc quantity_desc amount_asc amount_desc].freeze
  PER_PAGE = 20

  included do
    scope :search_card_name, lambda { |q|
      q = q.to_s.strip
      q.blank? ? all : where(arel_table[:card_name].matches("%#{sanitize_sql_like(q)}%"))
    }
    scope :sorted_by, lambda { |sort|
      normalized_sort = normalize_sort(sort)
      if normalized_sort.nil?
        order(id: :asc)
      else
        order_clause = case normalized_sort
        when "card_name_asc"
          "#{table_name}.card_name COLLATE \"C\" ASC"
        when "card_name_desc"
          "#{table_name}.card_name COLLATE \"C\" DESC"
        when "quantity_asc"
          "quantity ASC"
        when "quantity_desc"
          "quantity DESC"
        when "amount_asc"
          arel_table[:amount].asc.nulls_last
        when "amount_desc"
          arel_table[:amount].desc.nulls_last
        end
        order(order_clause).order(id: :asc)
      end
    }
  end

  class_methods do
    def normalize_sort(value)
      value = value.to_s.strip
      SORT_OPTIONS.include?(value) ? value : nil
    end
  end
end
