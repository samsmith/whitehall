class DocumentSeries < ActiveRecord::Base
  belongs_to :organisation

  has_many :editions

  validates :name, presence: true

  before_destroy { |dc| dc.destroyable? }

  def published_editions
    editions.published
  end

  protected

  def destroyable?
    editions.empty?
  end
end