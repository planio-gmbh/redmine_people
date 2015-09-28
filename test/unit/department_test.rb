require File.expand_path('../../test_helper', __FILE__)

class DepartmentTest < ActiveSupport::TestCase
  
  fixtures :users
  fixtures :email_addresses if ActiveRecord::VERSION::MAJOR >= 4

  RedminePeople::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_people).directory + '/test/fixtures/',
                            [:people_information, :departments])

  def setup
    #     1   2
    #    /|
    #   3 4
    #     |
    #     5
    #
    @first = Department.find(1)
    @second = Department.find(2)

    @third = Department.create!(:name => 'third', :parent_id => @first.id)
    @fourth = Department.create!(:name => 'fourth', :parent_id => @first.id)
    @fifth = Department.create!(:name => 'fifth', :parent_id => @fourth.id)

    [@first, @second, @third, @fourth, @fifth].each do |d|
      d.reload
    end
  end

  def test_people
    assert_equal [4], Department.find(1).people.map(&:id)
    assert_equal [1], Department.find(2).people.map(&:id)
  end

  def test_department_tree
    departments0 = []
    departments1 = []

    Department.department_tree(Department.all) do |department, level|
      if level == 0
        departments0.push(department.name)
      elsif level == 1
        departments1.push(department.name)
      end
    end
    assert_equal ['FBI department 1', 'FBI department 2'].sort , departments0.sort
    assert_equal ['third', 'fourth'].sort , departments1.sort
  end

  def test_nested_set_structure
    assert_equal [1,8], [@first.lft, @first.rgt]
    assert_equal [9,10],[@second.lft, @second.rgt]
    assert_equal [@fourth.lft, @fourth.rgt], [@fifth.lft - 1, @fifth.rgt + 1]
  end

  def test_allowed_parents
    assert_equal ["FBI department 2"], @first.allowed_parents.compact.map(&:name).sort
    assert_equal ["FBI department 1", "fifth", "fourth", "third"], @second.allowed_parents.compact.map(&:name).sort
    assert_equal ["FBI department 1", "FBI department 2", "third"], @fourth.allowed_parents.compact.map(&:name).sort
    assert_equal ["FBI department 1", "FBI department 2", "fourth", "third"], @fifth.allowed_parents.compact.map(&:name).sort
  end

end
