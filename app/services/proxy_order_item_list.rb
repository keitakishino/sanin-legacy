class ProxyOrderItemList
  SORTS = %w[registered name_asc name_desc unit_price_asc unit_price_desc].freeze
  DEFAULT_SORT = "registered"

  def initialize(items, calculator:, query: nil, sort: nil)
    @all_items = items.to_a
    @calculator = calculator
    @query = query.is_a?(String) ? query.strip : ""
    @sort = SORTS.include?(sort) ? sort : DEFAULT_SORT
    @total_count = @all_items.size
    @items = apply_filters_and_sort
  end

  def items
    @items
  end

  def query
    @query
  end

  def sort
    @sort
  end

  def total_count
    @total_count
  end

  def visible_count
    @items.size
  end

  def filtering?
    @query.present?
  end

  def include?(item)
    @items.any? { |i| i.id == item.id }
  end

  def to_params
    { q: @query.presence, sort: (@sort unless @sort == DEFAULT_SORT) }.compact
  end

  private

  def apply_filters_and_sort
    filtered = filter_items
    sort_items(filtered)
  end

  def filter_items
    return @all_items if @query.blank?

    @all_items.select do |item|
      item.card_name.to_s.downcase.include?(@query.downcase)
    end
  end

  def sort_items(items)
    case @sort
    when "name_asc"
      items.sort_by { |i| [ i.card_name.to_s.downcase, i.id ] }
    when "name_desc"
      items.sort_by { |i| [ i.card_name.to_s.downcase, i.id ] }.reverse
    when "unit_price_asc"
      items.sort_by { |i| [ @calculator.unit_price(i), i.id ] }
    when "unit_price_desc"
      items.sort_by { |i| [ -@calculator.unit_price(i), i.id ] }
    else # registered
      items.sort_by(&:id)
    end
  end
end
