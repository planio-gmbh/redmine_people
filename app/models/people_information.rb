# This file is a part of Redmine CRM (redmine_contacts) plugin,
# customer relationship management plugin for Redmine
#
# Copyright (C) 2011-2015 Kirill Bezrukov
# http://www.redminecrm.com/
#
# redmine_people is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_people is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_people.  If not, see <http://www.gnu.org/licenses/>.

class PeopleInformation < ActiveRecord::Base
  self.table_name = "people_information"
  self.primary_key = 'user_id'

  belongs_to :person, :foreign_key => :user_id
  belongs_to :department

  attr_accessible :phone, :address, :skype, :birthday, :job_title, :company, :middlename, :gender, :twitter,
                  :facebook, :linkedin, :department_id, :background, :appearance_date

  def self.reject_information(attributes)
    exists = attributes['id'].present?
    empty = PeopleInformation.accessible_attributes.to_a.map{|name| attributes[name].blank?}.all?
    attributes.merge!({:_destroy => 1}) if exists and empty
    return (!exists and empty)
  end

end
