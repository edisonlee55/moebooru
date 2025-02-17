require "test_helper"

class UserControllerTest < ActionController::TestCase
  fixtures :users, :table_data

  def setup_action_mailer
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def create_user(name, params = {})
    user = User.new({ :password => "zugzug1", :password_confirmation => "zugzug1", :email => "a@b.net" }.merge(params))
    user.name = name
    user.level = CONFIG["user_levels"]["Member"]
    user.save
    user
  end

  def test_show
    get :show, :params => { :id => 1 }, :session => { :user_id => 1 }
    assert_response :success
  end

  def test_invites
    setup_action_mailer

    member = User.find(4)

    # Should fail
    post :invites, :params => { :member => { :name => "member", :level => 33 } }, :session => { :user_id => 2 }
    member.reload
    assert_equal(CONFIG["user_levels"]["Member"], member.level)

    # Should fail
    mod = User.find(2)
    mod.invite_count = 10
    mod.save
    ur = UserRecord.create(:user_id => 4, :is_positive => false, :body => "bad", :reported_by => 1)
    post :invites, :params => { :member => { :name => "member", :level => 33 } }, :session => { :user_id => 2 }
    member.reload
    assert_equal(CONFIG["user_levels"]["Member"], member.level)

    ur.destroy

    # Should succeed
    post :invites, :params => { :member => { :name => "member", :level => 50 } }, :session => { :user_id => 2 }
    member.reload
    assert_equal(CONFIG["user_levels"]["Contributor"], member.level)
  end

  def test_home
    get :home
    assert_response :success

    get :home, :session => { :user_id => 1 }
    assert_response :success
  end

  def test_index
    get :index
    assert_response :success

    # TODO: more parameters
  end

  def test_authentication_failure
    create_user("bob")

    get :login
    assert_response :success

    post :authenticate, :params => { :user => { :name => "bob", :password => "zugzug2" } }
    assert_not_nil(assigns(:current_user))
    assert_equal(true, assigns(:current_user).is_anonymous?)
  end

  def test_authentication_success
    create_user("bob")

    post :authenticate, :params => { :user => { :name => "bob", :password => "zugzug1" } }
    assert_not_nil(assigns(:current_user))
    assert_equal(false, assigns(:current_user).is_anonymous?)
    assert_equal("bob", assigns(:current_user).name)
  end

  def test_create
    setup_action_mailer

    get :signup
    assert_response :success

    post :create, :params => { :user => { :name => "mog", :email => "mog@danbooru.com", :password => "zugzug1", :password_confirmation => "zugzug1" } }
    mog = User.find_by_name("mog")
    assert_not_nil(mog)
  end

  def test_update
    get :edit, :session => { :user_id => 4 }
    assert_response :success

    original_invite_count = User.find(4).invite_count
    post :update, :params => { :user => { :invite_count => original_invite_count + 2 } }, :session => { :user_id => 4 }
    assert_equal(original_invite_count, User.find(4).invite_count)

    post :update, :params => { :user => { :receive_dmails => true } }, :session => { :user_id => 4 }
    assert_equal(true, User.find(4).receive_dmails?)
  end

  def test_reset_password
    setup_action_mailer

    old_password_hash = User.find(1).password_hash

    get :reset_password
    assert_response :success

    post :reset_password, :params => { :user => { :name => "admin", :email => "wrong@danbooru.com" } }
    assert_equal(old_password_hash, User.find(1).password_hash)

    post :reset_password, :params => { :user => { :name => "admin", :email => "admin@danbooru.com" } }
    assert_not_equal(old_password_hash, User.find(1).password_hash)
  end

  def test_block
    setup_action_mailer

    get :block, :params => { :id => 4 }, :session => { :user_id => 1 }
    assert_response :success

    post :block, :params => { :id => 4, :ban => { :reason => "bad", :duration => 5 } }, :session => { :user_id => 1 }
    banned = User.find(4)
    assert_equal(CONFIG["user_levels"]["Blocked"], banned.level)

    post :unblock, :params => { :user => { "4" => "1" } }, :session => { :user_id => 1 }
    banned.reload
    assert_equal(CONFIG["user_levels"]["Member"], banned.level)
  end

  def test_show_blocked_users
    setup_action_mailer

    get :show_blocked_users, :session => { :user_id => 1 }
    assert_response :success
  end
end
