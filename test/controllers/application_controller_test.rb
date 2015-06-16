require 'test_helper'

describe 'ApplicationController' do
  describe 'TestController' do
    setup do
      @controller = TestController.new
      @controller.request = @request
      @controller.response = @response
    end

    it 'render_404 as html' do
      get :renders_404
      must_respond_with :not_found
      response.body.must_include(I18n.t('application.error.header'))
      response.headers['Content-Type'].must_include('text/html')
    end

    it 'render_404 as json' do
      get :renders_404, format: 'json'
      must_respond_with :not_found
      response.body.must_include(I18n.t(:four_oh_four))
      response.headers['Content-Type'].must_include('application/json')
    end

    it 'render_404 as xml' do
      get :renders_404, format: 'xml'
      must_respond_with :not_found
      response.body.must_include(I18n.t(:four_oh_four))
      response.headers['Content-Type'].must_include('application/xml')
    end

    it 'error message as html' do
      get :error_with_message
      must_respond_with :unauthorized
      response.body.must_include(I18n.t('application.error.header'))
    end

    it 'error message as json' do
      get :error_with_message, format: 'json'
      must_respond_with :unauthorized
      response.body.must_include('test error string')
    end

    it 'error message as xml' do
      get :error_with_message, format: 'xml'
      must_respond_with :unauthorized
      response.body.must_include('test error string')
    end

    it 'does not invoke airbrake on routing errors' do
      Rails.application.config.stubs(:consider_all_requests_local).returns false
      @controller.expects(:notify_airbrake).never
      get :throws_routing_error
      must_respond_with :not_found
      Rails.application.config.unstub(:consider_all_requests_local)
    end

    it 'does not invoke airbrake on param not found errors' do
      Rails.application.config.stubs(:consider_all_requests_local).returns false
      @controller.expects(:notify_airbrake).never
      get :throws_param_record_not_found
      must_respond_with :not_found
      Rails.application.config.unstub(:consider_all_requests_local)
    end

    it 'does invoke airbrake on generic errors' do
      Rails.application.config.stubs(:consider_all_requests_local).returns false
      @controller.expects(:notify_airbrake).once
      get :throws_standard_error
      must_respond_with :not_found
      Rails.application.config.unstub(:consider_all_requests_local)
    end

    it 'does not prevent sandard errors from being shown to developers' do
      Rails.application.config.stubs(:consider_all_requests_local).returns true
      @controller.expects(:notify_airbrake).never
      -> { get :throws_standard_error }.must_raise(StandardError)
      Rails.application.config.unstub(:consider_all_requests_local)
    end

    it 'session_required with a current user' do
      login_as create(:account)
      get :session_required_action
      must_respond_with :ok
    end

    it 'session_required without a current user' do
      login_as nil
      get :session_required_action
      must_respond_with :redirect
      must_redirect_to new_session_path
    end

    it 'admin_session_required with a current admin' do
      login_as create(:admin)
      get :admin_session_required_action
      must_respond_with :ok
    end

    it 'admin_session_required without a current user' do
      login_as nil
      get :admin_session_required_action
      must_respond_with :unauthorized
    end

    it 'admin_session_required with a current plain user' do
      login_as create(:account)
      get :admin_session_required_action
      must_respond_with :unauthorized
    end

    it 'ParamRecordNotFound exceptions are caught and not passed on as 500s' do
      get :throws_param_record_not_found
      must_respond_with :not_found
    end

    it 'remember me functionality automatically logs users in' do
      login_as nil
      admin = create(:admin)
      Account::Authenticator.remember(admin)
      @request.cookies[:auth_token] = admin.remember_token
      get :session_required_action
      must_respond_with :ok
      session[:account_id].must_equal admin.id
    end
  end

  describe 'ProjectsController' do
    setup do
      @controller = ProjectsController.new
      @controller.request = @request
      @controller.response = @response
    end

    it 'clears reminders' do
      user = create(:account)
      project = create(:project)
      action = user.actions.create!(status: Action::STATUSES[:remind], stack_project: project)

      login_as user
      get :show, id: create(:project).to_param
      @response.body.must_match(/You can add more projects now./)
      assert_response :success
      action.reload.status.must_equal Action::STATUSES[:remind]

      get :show, id: create(:project).url_name, clear_action_reminder: action.id
      @response.body.wont_match(/You can add more projects now./)
      assert_response :success
      action.reload.status.must_equal Action::STATUSES[:completed]
    end
  end

  describe 'AccountsController' do
    before do
      @controller = AccountsController.new
      @controller.request = @request
      @controller.response = @response
    end

    describe 'alert_non_activated_account' do
      let(:non_activated_message) do
        I18n.t('non_activated_message', link: @controller.view_context.link_to(:here, new_activation_resend_path))
      end

      it 'wont show flash message when logged out' do
        account = create(:account, activated_at: nil)

        get :show, id: account.id
        flash[:notice].must_be_nil
      end

      it 'must set flash message when account is not activated' do
        account = create(:account, activated_at: nil)
        login_as account

        get :show, id: account.id
        flash[:notice].must_equal non_activated_message
      end

      it 'wont set flash message for activated accounts' do
        account = create(:account)
        login_as account

        get :show, id: account.id
        flash[:notice].wont_equal non_activated_message
      end

      it 'wont display non activated message when notice already exists' do
        account = create(:account, activated_at: nil)
        login_as account

        patch :update, id: account.id, account: { url: Faker::Internet.url }

        flash[:notice].wont_equal non_activated_message
      end
    end
  end
end

class TestController < ApplicationController
  before_filter :session_required, only: :session_required_action
  before_filter :admin_session_required, only: :admin_session_required_action

  def renders_404
    render_404
  end

  def error_with_message
    error(message: 'test error string', status: :unauthorized)
  end

  def session_required_action
    render nothing: true
  end

  def admin_session_required_action
    render nothing: true
  end

  def throws_param_record_not_found
    fail ParamRecordNotFound
  end

  def throws_routing_error
    fail ActionController::RoutingError, 'i_am_a_banana'
  end

  def throws_standard_error
    fail StandardError
  end
end

test_routes = proc do
  get 'test/renders_404' => 'test#renders_404'
  get 'test/error_with_message' => 'test#error_with_message'
  get 'test/session_required_action' => 'test#session_required_action'
  get 'test/admin_session_required_action' => 'test#admin_session_required_action'
  get 'test/throws_param_record_not_found' => 'test#throws_param_record_not_found'
  get 'test/throws_routing_error' => 'test#throws_routing_error'
  get 'test/throws_standard_error' => 'test#throws_standard_error'
end
Rails.application.routes.send(:eval_block, test_routes)
