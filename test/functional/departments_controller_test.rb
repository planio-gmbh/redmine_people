require File.expand_path('../../test_helper', __FILE__)

class DepartmentsControllerTest < ActionController::TestCase
  
  fixtures :users
  fixtures :email_addresses if ActiveRecord::VERSION::MAJOR >= 4

  RedminePeople::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_people).directory + '/test/fixtures/',
                            [:departments, :people_information])

  def setup
    @person = Person.find(4)
    @department = Department.find(2)
  end

  def access_message(action)
    "No access for the #{action} action"
  end

  def test_without_authorization
    # Get
    [:index, :show].each do |action|
      get action, :id => @department.id
      assert_response :success, access_message(action)
    end

    [:new, :edit].each do |action|
      get action, :id => @department.id
      assert_response 302, access_message(action)
    end

    # Post
    [:update, :destroy, :create].each do |action|
      post action, :id => @department.id
      assert_response 302, access_message(action)
    end
  end

  def test_with_deny_user
    @request.session[:user_id] = 2
    # Post
    [:update, :destroy, :create].each do |action|
      post action, :id => @department.id
      assert_response 403, access_message(action)
    end
  end

  def test_get_index
    @request.session[:user_id] = 1

    get :index
    assert_response :success
    assert_select 'a', /FBI department 1/
    assert_select 'a', /FBI department 2/
  end

  def test_get_show
    @request.session[:user_id] = 1
    get :show, :id => @department.id
    assert_select 'h3', /FBI department 2/
  end

  def test_post_create
    @request.session[:user_id] = 1
    post :create, :department => { :name => 'New Department' }
    assert_response 302
    assert_equal 'New Department', Department.last.name
  end

  def test_post_update
    @request.session[:user_id] = 1
    post :update, :id => @department.id, :department => { :name => 'New Department' }
    assert_response 302
    @department.reload
    assert_equal 'New Department', @department.name
  end

  def test_post_destroy
    @request.session[:user_id] = 1
    post :destroy, :id => @department.id
    assert_response 302
    assert_raises(ActiveRecord::RecordNotFound) do
      Department.find(2)
    end
  end

  def test_add_people_to_department
    @request.session[:user_id] = 1
    post :add_people, :id => @department.id, :person_id => @person.id
    assert_response 302
    assert_equal @department.id, @person.department_id
  end

  def test_remove_person
    @request.session[:user_id] = 1
    post :remove_person, :id => @department.id, :person_id => @person.id
    assert_response 302
    assert (not @department.people.include? @person)
  end

end
