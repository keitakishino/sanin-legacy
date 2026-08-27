class Event < ApplicationRecord
  # Associations
  belongs_to :created_by, class_name: "User", optional: true

  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :event_date, presence: true

  # Scopes for logical deletion
  default_scope { where(discarded_at: nil) }
  scope :with_discarded, -> { unscope(where: :discarded_at) }
  scope :only_discarded, -> { with_discarded.where.not(discarded_at: nil) }

  # Logical deletion methods
  def discard!
    update(discarded_at: Time.current)
  end

  def restore!
    update(discarded_at: nil)
  end

  def discarded?
    discarded_at.present?
  end
end
