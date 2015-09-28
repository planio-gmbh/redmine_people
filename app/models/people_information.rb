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
