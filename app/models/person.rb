class Person < User
  unloadable
  include Redmine::SafeAttributes

  self.inheritance_column = :_type_disabled
  
  has_one :information, :class_name => "PeopleInformation", :foreign_key => :user_id, :dependent => :destroy

  delegate :phone, :address, :skype, :birthday, :job_title, :company, :middlename, :gender, :twitter,
          :facebook, :linkedin, :department_id, :background, :appearance_date,
          :to => :information, :allow_nil => true

  accepts_nested_attributes_for :information, :allow_destroy => true, :update_only => true, :reject_if => proc {|attributes| PeopleInformation.reject_information(attributes)}
  
  has_one :department, :through => :information
  
  GENDERS = [[l(:label_people_male), 0], [l(:label_people_female), 1]]

  scope :in_department, lambda {|department|
    department_id = department.is_a?(Department) ? department.id : department.to_i
    eager_load(:information).where("(#{PeopleInformation.table_name}.department_id = ?) AND (#{Person.table_name}.type = 'User')", department_id)
  }
  scope :not_in_department, lambda {|department|
    department_id = department.is_a?(Department) ? department.id : department.to_i
    eager_load(:information).where("(#{PeopleInformation.table_name}.department_id != ?) OR (#{PeopleInformation.table_name}.department_id IS NULL)", department_id)
  }

  scope :seach_by_name, lambda {|search| eager_load(ActiveRecord::VERSION::MAJOR >= 4 ? [:information, :email_address] : [:information]).where("(LOWER(#{Person.table_name}.firstname) LIKE :search OR
                                                                    LOWER(#{Person.table_name}.lastname) LIKE :search OR
                                                                    LOWER(#{PeopleInformation.table_name}.middlename) LIKE :search OR
                                                                    LOWER(#{Person.table_name}.login) LIKE :search OR
                                                                    LOWER(#{(ActiveRecord::VERSION::MAJOR >= 4) ? (EmailAddress.table_name + '.address') : (Person.table_name + '.mail')}) LIKE :search)", {:search => search.downcase + "%"} )}

  validates_uniqueness_of :firstname, :scope => :lastname
  
  safe_attributes 'custom_field_values',
                  'custom_fields',
                  'information_attributes',
  :if => lambda {|person, user| (person.new_record? && user.allowed_people_to?(:add_people, person)) || user.allowed_people_to?(:edit_people, person) }

  safe_attributes 'status',
    :if => lambda {|person, user| user.allowed_people_to?(:edit_people, person) && person.id != user.id && !person.admin }

  def type
    'User'
  end

  def email
    self.mail
  end

  def project
    nil
  end

  def phones
    @phones || self.phone ? self.phone.split( /, */) : []
  end

  def next_birthday
    return if birthday.blank?
    year = Date.today.year
    mmdd = birthday.strftime('%m%d')
    year += 1 if mmdd < Date.today.strftime('%m%d')
    mmdd = '0301' if mmdd == '0229' && !Date.parse("#{year}0101").leap?
    return Date.parse("#{year}#{mmdd}")
  end

  def self.next_birthdays(limit = 10)
    Person.eager_load(:information).where("#{PeopleInformation.table_name}.birthday IS NOT NULL").sort_by(&:next_birthday).first(limit)
  end

  def age
    return nil if birthday.blank?
    now = Time.now
    age = now.year - birthday.year - (birthday.to_time.change(:year => now.year) > now ? 1 : 0)
  end

  def editable_by?(usr, prj=nil)
    true
    # usr && (usr.allowed_to?(:edit_people, prj) || (self.author == usr && usr.allowed_to?(:edit_own_invoices, prj)))
    # usr && usr.logged? && (usr.allowed_to?(:edit_notes, project) || (self.author == usr && usr.allowed_to?(:edit_own_notes, project)))
  end

  def visible?(user=User.current)
    if Redmine::VERSION.to_s >= "3.0"
      principal = Principal.visible(user).where(:id => id).first
      return principal.present?
    end
    true
  end

  def attachments_visible?(user=User.current)
    true
  end

end
