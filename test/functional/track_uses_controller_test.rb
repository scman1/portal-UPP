require 'test_helper'

class TrackUsesControllerTest < ActionController::TestCase
  setup do
    @track_use = track_uses(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:track_uses)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create track_use" do
    assert_difference('TrackUse.count') do
      post :create, track_use: { message: @track_use.message, user: @track_use.user }
    end

    assert_redirected_to track_use_path(assigns(:track_use))
  end

  test "should show track_use" do
    get :show, id: @track_use
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @track_use
    assert_response :success
  end

  test "should update track_use" do
    put :update, id: @track_use, track_use: { message: @track_use.message, user: @track_use.user }
    assert_redirected_to track_use_path(assigns(:track_use))
  end

  test "should destroy track_use" do
    assert_difference('TrackUse.count', -1) do
      delete :destroy, id: @track_use
    end

    assert_redirected_to track_uses_path
  end
end
