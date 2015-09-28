require File.expand_path('../../test_helper', __FILE__)

class PeopleControllerTest < ActionController::TestCase

  fixtures :users
  fixtures :email_addresses if ActiveRecord::VERSION::MAJOR >= 4

  RedminePeople::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_people).directory + '/test/fixtures/',
                            [:departments, :people_information])

  def setup
    @person = Person.find(4)
  end

  def access_message(action)
    "No access for the #{action} action"
  end

  def test_without_authorization
    # Get
    [:index, :show, :new, :edit].each do |action|
      get action, :id => @person.id
      assert_response 302, access_message(action)
    end

    # Post
    [:update, :destroy, :create].each do |action|
      post action, :id => @person.id
      assert_response 302, access_message(action)
    end
  end

  def test_with_deny_user
    @request.session[:user_id] = 2
    # Get
    [:show, :index, :new, :edit].each do |action|
      get action, :id => @person.id
      assert_response 403, access_message(action)
    end

    # Post
    [:update, :destroy, :create].each do |action|
      post action, :id => @person.id
      assert_response 403, access_message(action)
    end
  end

  def test_get_index
    @request.session[:user_id] = 1
    get :index
    assert_response :success
    assert_template :index
  end

  def test_get_index_with_name
    @request.session[:user_id] = 1
    get :index, :name => 'Admin', :xhr => true
    assert_select 'h1 a', {:count => 0, :text => /Hill Robert/}
    assert_select 'h1 a', 'Redmine Admin'
  end

  def test_get_index_with_department
    @request.session[:user_id] = 1
    get :index, :department_id => 2
    assert_select 'h1 a', {:count => 0, :text => /Hill Robert/}
    assert_select 'h1 a', 'Redmine Admin'
  end

  def test_get_show
    @request.session[:user_id] = 1
    get :show , :id => @person.id
    assert_response :success
    assert_select 'h1', /Robert Hill/
  end

  def test_get_new
    @request.session[:user_id] = 1
    get :new
    assert_response :success
  end

  def test_get_edit
    @request.session[:user_id] = 1
    get :edit , :id => @person.id
    assert_response :success
    assert_select "input[value='Hill']"
  end

  def test_post_create
    @request.session[:user_id] = 1
    post :create,
         :person => {
                    :login => 'login',
                    :password => '12345678',
                    :password_confirmation => '12345678',
                    :firstname => 'Ivan',
                    :lastname => 'Ivanov',
                    :mail => 'ivan@ivanov.com',
                    :information_attributes => {
                      :facebook => 'Facebook',
                      :middlename => 'Ivanovich'
                    }
                   }
    person = Person.last
    assert_redirected_to :action => 'show', :id => person.id
    assert_equal ['ivan@ivanov.com','Ivanovich'], [person.email, person.middlename]
  end

  def test_put_update
    @request.session[:user_id] = 1
    post :update,
        :id => @person.id,
        :person => {
                     :firstname => 'firstname',
                     :information_attributes => {
                      :facebook => 'Facebook2',
                    }
                   }
    @person.reload
    assert_redirected_to :action => 'show', :id => @person.id
    assert_equal ['firstname','Facebook2'], [@person.firstname, @person.facebook]
  end

  def test_destroy
    @request.session[:user_id] = 1
    post :destroy, :id => 4
    assert_redirected_to :action => 'index'
    assert_raises(ActiveRecord::RecordNotFound) do
      Person.find(4)
    end
  end

end
