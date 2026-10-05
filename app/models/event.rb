class Event < ApplicationRecord
  # Associations
  belongs_to :created_by, class_name: "User"
  # Note: Trades are kept even if Event is physically deleted (rare), to maintain trade history integrity.
  # Design: Events use soft delete (discarded_at), so dependent: :destroy doesn't actually execute.
  # If physical deletion ever occurs, DB foreign key constraint (ON DELETE RESTRICT) will prevent cascade deletion.
  has_many :trades

  # Validations
  validates :created_by, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :event_date, presence: true
  validate :event_date_not_in_past, on: %i[create update]

  # Scopes for logical deletion
  default_scope { where(discarded_at: nil) }
  scope :with_discarded, -> { unscope(where: :discarded_at) }
  scope :only_discarded, -> { with_discarded.where.not(discarded_at: nil) }
  scope :not_past, -> { where(event_date: current_date..) }

  class << self
    def current_date
      Time.find_zone!("Asia/Tokyo").today
    end
  end

  # Logical deletion methods
  def discard!
    @discard_failures = []
    transaction do
      self.discarded_at = Time.current
      @discard_failures << self unless save(context: :discard)
      trades.each do |trade|
        @discard_failures.concat(trade.discard_failures) unless trade.discard!
      end
      raise ActiveRecord::Rollback if @discard_failures.any?
    end
    self.discarded_at = nil if @discard_failures.any?
    @discard_failures.empty?
  end

  def discard_failures
    @discard_failures || []
  end

  def restore!
    update(discarded_at: nil)
  end

  def discarded?
    discarded_at.present?
  end

  def past?
    event_date.present? && event_date < self.class.current_date
  end

  private

  def event_date_not_in_past
    errors.add(:event_date, :date_must_not_be_past) if event_date.present? && event_date < self.class.current_date
  end
end
