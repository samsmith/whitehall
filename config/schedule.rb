$: << '.'
require File.dirname(__FILE__) + "/initializers/scheduled_publishing"

# Run every SCHEDULED_PUBLISHING_PRECISION_IN_MINUTES minutes, 2 minutes before the due moment
# this allows the the ruby process (and rails) time to boot up. The scheduler then sleeps until
# the edition is due
every '13,28,43,58 * * * *', roles: [:backend] do
  rake "publishing:due:publish"
end

every :day, roles: [:frontend] do
  runner 'script/document_dump.rb'
end