class PopulatePeopleInformation < ActiveRecord::Migration
  def self.up
    sql = "INSERT INTO #{PeopleInformation.table_name} (user_id, phone, address, skype, " +
          " birthday, job_title, company, middlename, gender, twitter, facebook, linkedin, background, appearance_date, department_id)" +
          " SELECT id, phone, address, skype, birthday, job_title, company, middlename, " +
          " gender, twitter, facebook, linkedin, background, appearance_date, department_id FROM #{User.table_name} WHERE type = 'User' ORDER BY id"
    PeopleInformation.connection.execute(sql)
  end

end
