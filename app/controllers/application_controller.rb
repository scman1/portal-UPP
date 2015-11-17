# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'authenticated_system'

class ApplicationController < ActionController::Base

  include Seek::Errors::ControllerErrorHandling
  include Seek::EnabledFeaturesFilter

  self.mod_porter_secret = PORTER_SECRET

  include CommonSweepers

  before_filter :log_extra_exception_data

  before_filter :set_i18n_locale_from_params

  after_filter :log_event

  include AuthenticatedSystem

  around_filter :with_current_user

  #rescue_from "ActionController::RoutingError", :with=>:render_routing_error

  before_filter :profile_for_login_required

  before_filter :project_membership_required,:only=>[:create,:new]

  before_filter :restrict_guest_user, :only => [:new, :edit, :batch_publishing_preview]
  helper :all

  layout Seek::Config.main_layout

  def with_current_user
    User.with_current_user current_user do
      yield
    end
  end

  def strip_root_for_xml_requests
    #intended to use as a before filter on requests that lack a single root model.
    #XML requests are required to have a single root node. This assumes the root node
    #will be named xml. Turns a params hash like.. {:xml => {:param_one => "val", :param_two => "val2"}}
    # into {:param_one => "val", :param_two => "val2"}

    #This should probably be used with prepend_before_filter, since some filters might need this to happen so they can check params.
    #see sessions controller for an example usage
    params[:xml].each {|k,v| params[k] = v} if request.format.xml? and params[:xml]
  end

  def set_no_layout
    self.class.layout nil
  end

  def base_host
    request.host_with_port
  end

  def application_root
    return  "http://#{base_host}"
  end
  helper_method :application_root
  
  #Overridden from restful_authentication
  #Does a second check that there is a profile assigned to the user, and if not goes to the profile
  #selection page (GET people/select)
  def authorized?
    if super
      redirect_to(select_people_path) if current_user.person.nil?
      true
    else
      false
    end
  end

  def is_user_activated
    if Seek::Config.activation_required_enabled && current_user && !current_user.active?
      error("Activation of this account it required for gaining full access", "Activation required?")
      false
    end
  end

  def is_current_user_auth
    begin
      @user = User.where(["id = ?", current_user.try(:id)]).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      error("User not found (id not authorized)", "is invalid (not owner)")
      return false
    end

    unless @user
      error("User not found (or not authorized)", "is invalid (not owner)")
      return false
    end
  end

  def is_user_admin_auth
    unless User.admin_logged_in?
      error("Admin rights required", "is invalid (not admin)")
      return false
    end
    return true
  end

  def is_admin_or_is_project_manager
    unless User.admin_logged_in? || User.project_manager_logged_in?
      error("You do not have the permission", "Not admin or #{t('project')} manager")
      return false
    end
  end

  def can_manage_announcements?
    User.admin_logged_in?
  end

  def logout_user
    current_user.forget_me if logged_in?
    cookies.delete :auth_token
    cookies.delete :open_id
    reset_session
  end

  private

  def restrict_guest_user
    if current_user && current_user.guest?
      flash[:error] = "You cannot perform this action as a Guest User. Please sign in or register for an account first."
      if !request.env["HTTP_REFERER"].nil?
        redirect_to :back
      else
        redirect_to main_app.root_path
      end
    end
  end

  def project_membership_required
    unless User.logged_in_and_member? || User.admin_logged_in?
      flash[:error] = "Only members of known projects, institutions or work groups are allowed to create new content."
      respond_to do |format|
        format.html do
          object = eval("@"+controller_name.singularize)
          if !object.nil? && object.try(:can_view?)
            redirect_to object
          else
            path = nil
            begin
              path = eval("main_app.#{controller_name}_path")
            rescue Exception=>e
              logger.error("No path found for controller - #{controller_name}",e)
              path = main_app.root_path
            end
            redirect_to path
          end

        end
        format.json { render :json => {:status => 401, :error_message => flash[:error]} }
      end
    end
  end

  alias_method :project_membership_required_appended, :project_membership_required


  #used to suppress elements that are for virtualliver only or are still currently being worked on
  def virtualliver_only
    if !Seek::Config.is_virtualliver
      error("This feature is is not yet currently available","invalid route")
      return false
    end
  end


  def currently_logged_in
    current_user.person
  end

  def error(notice, message)
    flash[:error] = notice
     (err = User.new.errors).add(:id, message)

    respond_to do |format|
      format.html { redirect_to root_url }
    end
  end

  #required for the Savage Beast
  def admin?
    User.admin_logged_in?
  end

  def email_enabled?
    Seek::Config.email_enabled
  end

  def profile_for_login_required
    if User.current_user
      if User.current_user.person.nil?
        flash[:notice]="You have successfully registered your account, but now must select a profile, or create your own."
        redirect_to main_app.select_people_path
      end
    end
  end

  def translate_action action_name
    case action_name
      when 'show', 'index', 'view', 'search', 'favourite', 'favourite_delete',
          'comment', 'comment_delete', 'comments', 'comments_timeline', 'rate',
          'tag', 'items', 'statistics', 'tag_suggestions', 'preview','runs','new_object_based_on_existing_one'
        'view'

      when 'download', 'named_download', 'launch', 'submit_job', 'data', 'execute','plot', 'explore','visualise' ,
          'export_as_xgmml', 'download_log', 'download_results', 'input', 'output', 'download_output', 'download_input',
          'view_result','compare_versions'
        'download'

      when 'edit', 'new', 'create', 'update', 'new_version', 'create_version',
          'destroy_version', 'edit_version', 'update_version', 'new_item',
          'create_item', 'edit_item', 'update_item', 'quick_add', 'resolve_link', 'describe_ports'
        'edit'

      when 'destroy', 'destroy_item', 'cancel'
        'delete'

      when 'manage', 'notification', 'read_interaction', 'write_interaction', 'report_problem'
          'manage'
      else
        nil
    end
  end

  #handles finding an asset, and responding when it cannot be found. If it can be found the item instance is set (e.g. @project for projects_controller)
  def find_requested_item
    name = self.controller_name.singularize
    object = name.camelize.constantize.find_by_id(params[:id])
    if (object.nil?)
      respond_to do |format|
        flash[:error] = "The #{name.humanize} does not exist!"
        format.rdf { render  :text=>"Not found",:status => :not_found }
        format.xml { render  :text=>"<error>404 Not found</error>",:status => :not_found }
        format.json { render :text=>"Not found", :status => :not_found }
        format.html { redirect_to eval "#{self.controller_name}_path" }
      end
    else
      eval "@#{name} = object"
    end
  end

  #handles finding and authorizing an asset for all controllers that require authorization, and handling if the item cannot be found
  def find_and_authorize_requested_item
    begin
      name = self.controller_name.singularize
      action = translate_action(action_name)

      return if action.nil?

      object = name.camelize.constantize.find(params[:id])

      if is_auth?(object, action)
        eval "@#{name} = object"
        params.delete :sharing unless object.can_manage?(current_user)
      else
        respond_to do |format|
          #TODO: can_*? methods should report _why_ you can't do what you want. Perhaps something similar to how active_record_object.save stores 'why' in active_record_object.errors
          if User.current_user.nil?
            flash[:error] = "You are not authorized to #{action} this #{name.humanize}, you may need to login first."
          else
            flash[:error] = "You are not authorized to #{action} this #{name.humanize}."
          end

          format.html do
            case action
              when 'publish'   then redirect_to object
              when 'manage'   then redirect_to object
              when 'edit'     then redirect_to object
              when 'download' then redirect_to object
              when 'delete' then redirect_to object
              else                 redirect_to eval "#{self.controller_name}_path"
            end
          end
          format.rdf { render :text => "You may not #{action} #{name}:#{params[:id]}", :status => :forbidden }
          format.xml { render :text => "You may not #{action} #{name}:#{params[:id]}", :status => :forbidden }
          format.json { render :text => "You may not #{action} #{name}:#{params[:id]}", :status => :forbidden }
        end
        return false
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        if eval("@#{name}").nil?
          flash[:error] = "The #{name.humanize.downcase} does not exist!"
        else
          flash[:error] = "You are not authorized to view #{name.humanize}"
        end
        format.rdf { render  :text=>"Not found",:status => :not_found }
        format.xml { render  :text=>"<error>404 Not found</error>",:status => :not_found }
        format.json { render :text=>"Not found", :status => :not_found }
        format.html { redirect_to eval "#{self.controller_name}_path" }
      end
      return false
    end
  end

  def is_auth? object, action
    if object.can_perform? action
      true
    elsif params[:code] && (action == 'view' || action == 'download')
      object.auth_by_code? params[:code]
    else
      false
    end
  end

  def log_event
    User.with_current_user current_user do
      c = self.controller_name.downcase
      a = self.action_name.downcase

      object = eval("@"+c.singularize)

      object=current_user if c=="sessions" #logging in and out is a special case

      #don't log if the object is not valid or has not been saved, as this will a validation error on update or create
      return if object.nil? || (object.respond_to?("new_record?") && object.new_record?) || (object.respond_to?("errors") && !object.errors.empty?)

      case c
        when "sessions"
          if ["create", "destroy"].include?(a)
            ActivityLog.create(:action => a,
                               :culprit => current_user,
                               :controller_name => c,
                               :activity_loggable => object,
                               :user_agent => request.env["HTTP_USER_AGENT"])
          end
        when "sweeps", "runs"
          if ["show", "update", "destroy", "download"].include?(a)
            ref = object.projects.first
          elsif a == "create"
            ref = object.workflow
          end

          check_log_exists(a, c, object)
          ActivityLog.create(:action => a,
                             :culprit => current_user,
                             :referenced => ref,
                             :controller_name => c,
                             :activity_loggable => object,
                             :data => object.title,
                             :user_agent => request.env["HTTP_USER_AGENT"])
          break
        when *Seek::Util.authorized_types.map { |t| t.name.underscore.pluralize.split('/').last } # TODO: Find a nicer way of doing this...
          a = "create" if a == "upload_for_tool"
          a = "update" if a == "new_version"
          a = "inline_view" if a == "explore"
          if ["show", "create", "update", "destroy", "download", "inline_view"].include?(a)
            check_log_exists(a, c, object)
            ActivityLog.create(:action => a,
                               :culprit => current_user,
                               :referenced => object.projects.first,
                               :controller_name => c,
                               :activity_loggable => object,
                               :data => object.title,
                               :user_agent => request.env["HTTP_USER_AGENT"])
          end
        when "people"
          if ["show", "create", "update", "destroy"].include?(a)
            ActivityLog.create(:action => a,
                               :culprit => current_user,
                               :controller_name => c,
                               :activity_loggable => object,
                               :data => object.title,
                               :user_agent => request.env["HTTP_USER_AGENT"])
          end
        when "search"
          if a=="index"
            ActivityLog.create(:action => "index",
                               :culprit => current_user,
                               :controller_name => c,
                               :user_agent => request.env["HTTP_USER_AGENT"],
                               :data => {:search_query => object, :result_count => @results.count})
          end
        when "content_blobs"
          a = "inline_view" if a=="view_pdf_content"
          if a=="inline_view" || (a=="download" && params['intent'].to_s != 'inline_view')
            activity_loggable = object.asset
            ActivityLog.create(:action => a,
                               :culprit => current_user,
                               :referenced => object,
                               :controller_name => c,
                               :activity_loggable => activity_loggable,
                               :user_agent => request.env["HTTP_USER_AGENT"],
                               :data => activity_loggable.title)
          end
      end

      expire_activity_fragment_cache(c, a)
    end
  end

  def expire_activity_fragment_cache(controller,action)
    if action!="show"
      @@auth_types ||=  Seek::Util.authorized_types.collect{|t| t.name.underscore.pluralize}
      if action=="download"
        expire_download_activity
      elsif action=="create" && controller!="sessions"
        expire_create_activity
      elsif action=="destroy"
        expire_create_activity
        expire_download_activity
      elsif action=="update" && @@auth_types.include?(controller) #may have had is permission changed
        expire_create_activity
        expire_download_activity
        expire_resource_list_item_action_partial
      end
    end
  end


  def check_log_exists action,controllername,object
    if action=="create"
      a=ActivityLog.where(
          :activity_loggable_type=>object.class.name,
          :activity_loggable_id=>object.id,
          :controller_name=>controllername,
          :action=>"create").first
      
      logger.error("ERROR: Duplicate create activity log about to be created for #{object.class.name}:#{object.id}") unless a.nil?
    end
  end

  def permitted_filters
    #placed this in a separate method so that other controllers could override it if necessary
    Seek::Util.persistent_classes.select {|c| c.respond_to? :find_by_id if c.name!="Globalize::ActiveRecord::Translation"}.map {|c| c.name.underscore}
  end

  def apply_filters(resources)
    filters = params[:filter] || {}

    #translate params that are send as an _id, like project_id=12 - which will usually be a consequence of nested routing
    params.keys.each do |key|
      if (key.end_with?("_id"))
        filters[key.gsub("_id", "")]=params[key]
      end
    end

    if filters.size>0
      params[:page]||="all"
      params[:filtered]=true
    end

    #apply_filters will be dispatching to methods based on the symbols in params[:filter].
    #Permitted filters protects us from shennanigans like params[:filter] => {:destroy => 'This will destroy your data'}
    filters.delete_if { |k, v| not (permitted_filters.include? k.to_s) }
    resources.select do |res|
      filters.all? do |filter, value|
        filter = filter.to_s
        klass = filter.camelize.constantize
        value = klass.find_by_id value.to_i

        case
          #first the special cases
          when filter == 'investigation' && res.respond_to?(:assays)
            res.assays.collect { |a| a.study.investigation_id }.include? value.id
          when filter == 'study' && res.respond_to?(:assays)
            res.assays.collect { |a| a.study_id }.include? value.id
          when filter == 'person' && res.class.is_asset?
            (res.creators.include?(value) || res.contributor== value || res.contributor.try(:person) == value)
          when filter == 'person' && (res.respond_to?(:contributor) || res.respond_to?(:creators) || res.respond_to?(:owner))
            people = [res.contributor,res.contributor.try(:person)]
            people = people | res.creators if res.respond_to?(:creators)
            people << res.owner if res.respond_to?(:owner)
            people.compact!
            people.include?(value)
          #then the general case
          when res.respond_to?("all_related_#{filter.pluralize}")
            res.send("all_related_#{filter.pluralize}").include?(value)
          when res.respond_to?("related_#{filter.pluralize}")
            res.send("related_#{filter.pluralize}").include?(value)
          when res.respond_to?(filter)
            res.send(filter) == value
          when res.respond_to?(filter.pluralize)
            res.send(filter.pluralize).include? value
          #defaults to false, if a filter is not recognised then nothing is return
          else
            false
        end
      end
    end
  end

  def log_extra_exception_data
      request.env["exception_notifier.exception_data"] = {
          :current_logged_in_user=>current_user
      }
  end
  protected
  def set_i18n_locale_from_params
    if params[:locale]
      if I18n.available_locales.include?(params[:locale].to_sym)
        I18n.locale = params[:locale]|| I18n.default_locale
      else
        flash.now[:notice] =
          "#{params[:locale]} translation not available now"
        logger.error flash.now[:notice]
      end
    end
  end
  def default_url_options
    { locale: I18n.locale }
  end

end



