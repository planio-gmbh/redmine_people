# encoding: utf-8
#
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

require File.expand_path('../../test_helper', __FILE__)

class PersonTest < ActiveSupport::TestCase

  fixtures :users, :projects, :roles, :members, :member_roles
  fixtures :email_addresses if ActiveRecord::VERSION::MAJOR >= 4

  RedminePeople::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_people).directory + '/test/fixtures/',
                            [:people_information, :departments])


  def setup
    # Remove accesses operations
    Setting.plugin_redmine_people = {}

    User.current = nil
    @params =  { 'firstname' => 'newName', 'mail' => 'new@mail.ru', 'information_attributes' => { 'phone' => '89555555555'}}
    @person = Person.find(4)
  end

  def test_save_without_access
    # Editing by an anonymous user
    @person.safe_attributes = @params
    @person.save!
    @person.reload
    assert_not_equal '89555555555', @person.phone

    # User changes himself but edit_own_data is disabled
    Setting.plugin_redmine_people['edit_own_data'] = '0'

    User.current = User.find(4)
    @person.safe_attributes = @params
    @person.save!
    assert_not_equal '89555555555', @person.phone
  end

  def test_save_with_edit_own_data_access
    User.current = User.find(4)
    Setting.plugin_redmine_people['edit_own_data'] = '1'

    @person.safe_attributes = @params
    @person.save!
    assert_equal 'newName', @person.reload.firstname
    assert_equal 'new@mail.ru', @person.email
    assert_equal '89555555555', @person.phone
  end

  def test_save_with_edit_people_access
    User.current = User.find(2)
    PeopleAcl.create(2, ['edit_people'])

    @person.safe_attributes = @params
    @person.save!
    assert_equal '89555555555', @person.phone
  end

  def test_destroy
    Person.find(4).destroy
    assert_nil PeopleInformation.where(:user_id => 4).first
  end

  def test_seach_by_name_scope
    # by first name
    assert_equal 4, Person.seach_by_name('Robert').first.id
    # by middle name
    assert_equal 4, Person.seach_by_name('Vahtang').first.id
    # by mail
    assert_equal 1, Person.seach_by_name(Person.find(1).email).first.id
  end

  def test_in_department_scope
    assert (not Person.in_department(1).any? )
    assert_equal [1,2,3], Person.in_department(2).map(&:id).sort
    assert_equal [4], Person.in_department(3).map(&:id)
  end

  def test_not_in_department_scope
    assert Person.not_in_department(1).map(&:id).include?(4)
    assert (not Person.not_in_department(2).map(&:id).include?(1))
  end
    
  def test_visible?
    if Redmine::VERSION.to_s >= "3.0"
      Member.delete_all
      MemberRole.delete_all

      role = Role.create!(:name => 'role', :users_visibility => 'members_of_visible_projects', :issues_visibility => 'all')

      project1 = Project.find(1)

      person2 = Person.find(2)
      person3 = Person.find(3)

      # There are no joint projects between person2 and person3
      Member.create_principal_memberships(person2, :project_id => project1.id, :role_ids => [role.id])
      assert (not person3.visible?(person2))

      # Adds the joint project
      Member.create_principal_memberships(person3, :project_id => project1.id, :role_ids => [role.id])
      assert person3.visible?(person2)
    end
  end

  def test_add_tag
    User.current = nil
    person = Person.find(4)
    assert (not person.tags.any?)

    # without access
    person.safe_attributes = { 'tag_list' => 'Tag1, Tag2'}
    person.save
    assert (not person.reload.tag_list.any?)

    # with access
    User.current = Person.find(1)
    person.safe_attributes = { 'tag_list' => 'Tag1, Tag2'}
    person.save    
    assert_equal ['Tag1', 'Tag2'], person.reload.tag_list.sort
  end


end
