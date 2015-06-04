module FancyMultiselectHelper
  #the point of this module is to decompose the 'fancy_multiselect' method which was becoming too large and complex.
  #This breaks it into submodules by feature.
  module Base
    def fancy_multiselect object, association, options = {}
      render :partial => 'assets/fancy_multiselect', :locals => options
    end
  end

  module AjaxPreview
    def fancy_multiselect object, association, options = {}
      #skip if preview is disabled
      return super if options.delete :preview_disabled

      #skip if controller class does not define a preview method
      begin
        const = "#{association.to_s.classify.pluralize}Controller".constantize
        return super unless const.method_defined?(:preview)
      rescue NameError=>e
        return super
      end

      #adds options to the dropdown used to select items to add to the multiselect.
      options[:possibilities_options] = {} unless options[:possibilities_options]
      onchange = options[:possibilities_options][:onchange] || ''
      onchange += remote_function(
          :method=>:get,
          :url=>{:action=>"preview", :controller=>"#{association}", :element=>"#{association}_preview"},
          :with=>"'id='+this.value",
          :before=>"show_ajax_loader('#{association}_preview')") + ';'

      options[:possibilities_options][:onchange] = onchange.html_safe
      options = options.reverse_merge :html_options => "style='float:left; width:66%' ".html_safe

      #after rendering the multiselect, throw in a preview box.
      super(object, association, options) + "\n".html_safe + render(:partial => 'assets/preview_box', :locals => {:preview_name => association.to_s.underscore})
    end
  end

  module HideButtonWhenDefaultIsSelected
    def fancy_multiselect object, association, options = {}
      options[:possibilities_options] = {} unless options[:possibilities_options]
      onchange = options[:possibilities_options][:onchange] || ''
      collection_id = options[:name].to_s.gsub(']','').gsub(/[^-a-zA-Z0-9:.]/, "_")
      possibilities_id = "possible_#{collection_id}"
      button_id = "add_to_#{collection_id}_link"
      hide_add_link_when_default_is_selected_js = "($F('#{possibilities_id}') == 0) ? $('#{button_id}').hide() : $('#{button_id}').show();".html_safe
      onchange += hide_add_link_when_default_is_selected_js
      options[:possibilities_options][:onchange] = onchange.html_safe
      super(object, association, options) + "\n<script type='text/javascript'>#{hide_add_link_when_default_is_selected_js}</script>\n".html_safe
    end
  end

  module OtherProjectsCheckbox
    def fancy_multiselect object, association, options = {}
      if options[:project_possibilities]
        type = object.class.name.underscore

        check_box_and_alternative_list = "".html_safe
        check_box_and_alternative_list << "<br/>".html_safe
        check_box_and_alternative_list << check_box_tag("include_other_project_#{association}", nil, false,
                                                {:onchange => "swapSelectListContents('possible_#{type}_#{association.to_s.singularize}_ids','alternative_#{association.to_s.singularize}_ids');".html_safe,
                                                :style => "margin-top:0.5em;"}).html_safe
        check_box_and_alternative_list <<  "Associate #{association.to_s.singularize.humanize.pluralize} from other #{t('project').pluralize}?".html_safe
        check_box_and_alternative_list << select_tag("alternative_#{association.to_s.singularize}_ids",
                                              options_for_select([["Select #{association.to_s.singularize.humanize} ...", 0]]|options[:project_possibilities].collect { |o| [truncate(h(o.title), :length => 120), o.id] }), {:style => 'display:none;'}).html_safe

        options[:association_step_content] = '' unless options[:association_step_content]
        options[:association_step_content] = (options[:association_step_content] + check_box_and_alternative_list).html_safe

        swap_project_possibilities_into_dropdown_js = "".html_safe
        swap_project_possibilities_into_dropdown_js << "<script type='text/javascript'>".html_safe
        swap_project_possibilities_into_dropdown_js << "swapSelectListContents('possible_#{type}_#{association.to_s.singularize}_ids','alternative_#{association.to_s.singularize}_ids');".html_safe
        swap_project_possibilities_into_dropdown_js << "</script>".html_safe

        super + swap_project_possibilities_into_dropdown_js
      else
        super
      end
    end
  end

  module SetDefaults
    def fancy_multiselect object, association, options = {}
      options[:object_type_text] = options[:object_class].name.underscore.humanize unless options[:object_type_text]
      with_new_link = options[:with_new_link] || false
      object_type_text = options[:object_type_text]
      object_type_text = (I18n.t 'biosamples.sample_parent_term').capitalize if object_type_text == 'Specimen'
      # added translations and passed them as parameters to the actual helper translation strings below
      object_type_text = I18n.t(object_type_text.parameterize.underscore.to_sym)
      association_text = " " + I18n.t(association) 

      #set default values for locals being sent to the partial
      #override default values with options passed in to the method
      options.reverse_merge! :intro => I18n.t('multyselect_intro', object_text: object_type_text.downcase, relation_text: association_text.downcase),
                             :button_text => I18n.t('multyselect_button', object_text: object_type_text.downcase),
                             :default_choice_text => I18n.t('multyselect_default', relation_text: association_text.downcase),
                             :name => "#{options[:object_class].name.underscore}[#{association.to_s.singularize}_ids]",
                             :possibilities => [],
                             :value_method => :id,
                             :text_method => :title,
                             :with_new_link => with_new_link,
                             :object_type_text=> object_type_text,
                             :association=>association

      options[:selected] = object.send(association).map(&options[:value_method]) unless options[:selected]

      super object, association, options
    end
  end

  module SetDefaultsWithReflection
    def fancy_multiselect object, association, options = {}

      if reflection = options[:object_class].reflect_on_association(association)
        required_access = reflection.options[:required_access] || :can_view?
        #get 'view' from :can_view?
        access = required_access.to_s.split('_').last.gsub('?','')
        association_class = options.delete(:association_class) || reflection.klass
        options[:project_possibilities] = authorised_assets(association_class, current_user.person.projects, access) if options[:other_projects_checkbox]
        options[:possibilities] = authorised_assets(association_class, nil, access) unless options[:possibilities]
      end

      super object, association, options
    end
  end

  module FoldingBox
    def fancy_multiselect object, association, options = {}
      hidden = options.delete(:hidden)
      object_type_text = options[:object_type_text] || options[:object_class].name.underscore.humanize
      object_type_text = (I18n.t 'biosamples.sample_parent_term') if object_type_text == 'Specimen'
      object_type_text = I18n.t(object_type_text.parameterize.underscore.to_sym).downcase
      asociation_text = " " + I18n.t(association).downcase 
      title = (help_icon(I18n.t('multyselect_info', object_text: object_type_text, relation: asociation_text)) + asociation_text) + (options[:required] ? ' <span class="required">*</span>'.html_safe : '')

      folding_box "add_#{association}_form", title , :hidden => hidden, :contents => super(object, association, options)
    end
  end

  module AssociationContentFromBlock
    def fancy_multiselect object, association, options = {}
      if block_given?
        options[:association_step_content] = '' unless options[:association_step_content]
        options[:association_step_content] = options[:association_step_content] + capture {yield}
        concat super(object, association, options)
      else
        super(object, association, options)
      end
    end
  end


  module StringOrObject
    def fancy_multiselect string_or_object, association, options = {}
      string_or_object = string_or_object.constantize if string_or_object.is_a? String
      if string_or_object.is_a? Class
        options[:object_class] = string_or_object
        string_or_object = nil
      else
        options[:object_class] = string_or_object.class
      end
      super(string_or_object, association, options)
    end
  end

  #commenting some of these out should be ok. The only one relied on by others is SetDefaults (and Base, of course).
  #Changing the order may break things. These are executed starting with the last one, and ending with Base.
  include Base
  include AjaxPreview
  include HideButtonWhenDefaultIsSelected
  include OtherProjectsCheckbox
  include SetDefaults
  include SetDefaultsWithReflection
  include FoldingBox
  include AssociationContentFromBlock
  include StringOrObject
end
