class PolicyPresenter < Draper::Base
  include EditionPresenterHelper

  decorates :policy

  def display_date_attribute_name
    :first_published_at
  end
end
