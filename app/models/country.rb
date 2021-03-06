class Country < ActiveRecord::Base
  FEATURED_COUNTRY_NAMES = ["Spain"]

  FEATURED_COUNTRY_URLS = {
    "Spain"  => ["http://ukinspain.fco.gov.uk"]
  }

  has_many :edition_countries
  has_many :editions,
            through: :edition_countries
  has_many :published_editions,
            through: :edition_countries,
            class_name: "Edition",
            conditions: { state: "published" },
            source: :edition
  has_many :featured_news_articles,
            through: :edition_countries,
            class_name: "NewsArticle",
            source: :edition,
            conditions: { "edition_countries.featured" => true,
                          "editions.state" => "published" }

  validates_with SafeHtmlValidator
  validates :name, presence: true

  extend FriendlyId
  friendly_id

  def featured?
    FEATURED_COUNTRY_NAMES.include?(name)
  end

  def self.featured
    where(name: FEATURED_COUNTRY_NAMES)
  end

  def urls
    FEATURED_COUNTRY_URLS[name] || []
  end
end
