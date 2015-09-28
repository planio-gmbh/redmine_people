require File.expand_path('../../test_helper', __FILE__)

class PeopleSettingsControllerTest < ActionController::TestCase

  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles
  fixtures :email_addresses if ActiveRecord::VERSION::MAJOR >= 4


  RedminePeople::TestCase.create_fixtures(Redmine::Plugin.find(:redmine_people).directory + '/test/fixtures/',
                            [:departments, :people_information])

  def setup
    @request.session[:user_id] = 1
    @user = User.find(4)
  end

  def test_get_index
    get :index
    assert_response :success
    assert_template :index
  end

  def test_put_update
    post :update, :id => 1, :settings => {:visibility => '1'}, :tab => 'general'
    assert_equal '1', Setting.plugin_redmine_people["visibility"]
    assert_redirected_to :action => 'index', :tab => 'general'
  end

  def test_post_destroy
    PeopleAcl.create(4, ['add_people'])

    post :destroy, :id => 4
    assert_equal false, @user.allowed_people_to?(:add_people, @user)
  end

  def test_post_create
    user = User.find(4)
    assert_equal false, @user.allowed_people_to?(:add_people, @user)

    @request.session[:user_id] = 1
    post :create, :user_ids => ['4'], :acls => ['add_people']
    assert @user.allowed_people_to?(:add_people, @user)
  end

end
