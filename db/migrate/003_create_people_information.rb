class CreatePeopleInformation < ActiveRecord::Migration
  def self.up
    create_table :people_information , :id => false do |t|
      t.primary_key :user_id
      t.string :phone
      t.string :address
      t.string :skype
      t.date :birthday
      t.string :job_title
      t.string :company
      t.string :middlename
      t.integer :gender, :limit => 1
      t.string :twitter
      t.string :facebook
      t.string :linkedin
      t.text :background
      t.date :appearance_date
      t.integer :department_id
    end
  end

  def self.down
    drop_table :people_information
  end

end
