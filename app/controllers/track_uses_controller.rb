class TrackUsesController < ApplicationController

  before_filter :require_login
 
  # GET /track_uses
  # GET /track_uses.json
  def index
    @track_uses = TrackUse.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @track_uses }
    end
  end

  # GET /track_uses/1
  # GET /track_uses/1.json
  def show
    @track_use = TrackUse.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @track_use }
    end
  end

  # GET /track_uses/new
  # GET /track_uses/new.json
  def new
    @track_use = TrackUse.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @track_use }
    end
  end

  # GET /track_uses/1/edit
  def edit
    @track_use = TrackUse.find(params[:id])
  end

  # POST /track_uses
  # POST /track_uses.json
  def create
    @track_use = TrackUse.new(params[:track_use])

    respond_to do |format|
      if @track_use.save
        format.html { redirect_to @track_use, notice: 'Track use was successfully created.' }
        format.json { render json: @track_use, status: :created, location: @track_use }
      else
        format.html { render action: "new" }
        format.json { render json: @track_use.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /track_uses/1
  # PUT /track_uses/1.json
  def update
    @track_use = TrackUse.find(params[:id])

    respond_to do |format|
      if @track_use.update_attributes(params[:track_use])
        format.html { redirect_to @track_use, notice: 'Track use was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @track_use.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /track_uses/1
  # DELETE /track_uses/1.json
  def destroy
    @track_use = TrackUse.find(params[:id])
    @track_use.destroy

    respond_to do |format|
      format.html { redirect_to track_uses_url }
      format.json { head :no_content }
    end
  end
private
 
  def require_login
    unless logged_in?
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path # halts request cycle
    end
  end
  
end
