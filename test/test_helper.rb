# Load the Redmine helper
require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

class RedminePeople::TestCase

  def self.create_fixtures(fixtures_directory, table_names, class_names = {})
    if ActiveRecord::VERSION::MAJOR >= 4
      ActiveRecord::FixtureSet.create_fixtures(fixtures_directory, table_names, class_names = {})
    else
      ActiveRecord::Fixtures.create_fixtures(fixtures_directory, table_names, class_names = {})
    end
  end

end