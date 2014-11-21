require 'test_helper'

class TavernaPlayerRunsControllerTest < ActionController::TestCase

  include AuthenticatedTestHelper

  def setup
    @controller = TavernaPlayer::RunsController.new
    # Enable attribution of anonymous runs to guest user
    SEEK::Application.configure do
      Settings.defaults[:magic_guest_enabled] = true
    end
  end

  def teardown
    SEEK::Application.configure do
      Settings.defaults[:magic_guest_enabled] = false
    end
  end

  test "sends email when failure reported" do
    run = Factory(:failed_run)

    login_as run.contributor

    assert run.reportable?
    assert !run.reported

    assert_emails 1 do
      post :report_problem, :id => run.id
    end

    assert_redirected_to run_path(run)
    assert assigns(:run).reported
  end

  test "guest can run public workflow" do
    workflow = Factory(:workflow, :policy => Factory(:public_policy, :access_type => Policy::VISIBLE))

    assert !User.logged_in?

    assert_difference('TavernaPlayer::Run.count', 1) do
      post :create, :run => {
          :workflow_id => workflow.id,
          :workflow_version => workflow.version,
          :embedded => false,
          :name => "test run",
          :inputs_attributes => [{:name => :input_points,
                                  :value => 'test',
                                  :file => nil}]
      }, :use_route => :taverna_player
    end

    assert_redirected_to run_path(assigns(:run))
    assert_equal User.guest, assigns(:run).contributor
    assert_equal 'test run', assigns(:run).title
  end
end
