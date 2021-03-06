module Edition::Organisations
  extend ActiveSupport::Concern

  class Trait < Edition::Traits::Trait
    def process_associations_before_save(edition)
      @edition.edition_organisations.each do |association|
        edition.edition_organisations.build(association.attributes.except("id"))
      end
    end
  end

  included do
    has_many :edition_organisations, foreign_key: :edition_id, dependent: :destroy
    has_many :organisations, through: :edition_organisations

    validate :at_least_one_organisation

    add_trait Trait
  end

  module ClassMethods
    def in_organisation(organisation)
      organisations = [*organisation]
      slugs = organisations.map(&:slug)
      where('exists (
               select * from edition_organisations eo_orgcheck
                 join organisations orgcheck on eo_orgcheck.organisation_id=orgcheck.id
               where
                 eo_orgcheck.edition_id=editions.id
               and orgcheck.slug in (?))', slugs)
    end
  end

  def association_with_organisation(organisation)
    edition_organisations.where(organisation_id: organisation.id).first
  end

  def skip_organisation_validation?
    false
  end

private
  def at_least_one_organisation
    unless skip_organisation_validation? || edition_organisations.any? || organisations.any?
      errors[:organisations] = "at least one required"
    end
  end
end
