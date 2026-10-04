class CardDetailList
  def initialize(scope, prefix:, params:)
    @scope = scope
    @prefix = prefix
    @params = params
  end

  attr_reader :prefix

  def q
    @q ||= @params["#{prefix}_q"].to_s.strip.presence
  end

  def sort
    @sort ||= @scope.klass.normalize_sort(@params["#{prefix}_sort"])
  end

  def all_count
    @all_count ||= @scope.count
  end

  def records
    @records ||= begin
      filtered = @scope.search_card_name(q).sorted_by(sort)
      rel = filtered.page(@params["#{prefix}_page"]).per(CardDetailListing::PER_PAGE)
      rel.out_of_range? && rel.total_pages > 0 ? filtered.page(rel.total_pages).per(CardDetailListing::PER_PAGE) : rel
    end
  end

  def total_count
    records.total_count
  end

  def from
    total_count.zero? ? 0 : records.offset_value + 1
  end

  def to
    records.offset_value + records.size
  end

  def searching?
    q.present?
  end

  def param_key(name)
    "#{prefix}_#{name}"
  end

  def sort_indicator(column)
    case sort
    when "#{column}_asc"
      "▲"
    when "#{column}_desc"
      "▼"
    else
      "↕"
    end
  end

  def next_sort(column)
    case sort
    when "#{column}_asc"
      "#{column}_desc"
    when "#{column}_desc"
      nil
    else
      "#{column}_asc"
    end
  end

  def self.state_keys(prefix)
    %W[#{prefix}_q #{prefix}_sort #{prefix}_page]
  end
end
