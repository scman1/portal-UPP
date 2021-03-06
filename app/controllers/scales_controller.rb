class ScalesController < ApplicationController

  def search
    type = params[:scale_type]
    scale = Scale.find_by_key(type)

    assets = scale ? Scale.with_scale(scale) : everything_with_scale

    resource_hash={}
    assets.each do |res|
      resource_hash[res.class.name] = {:items => [], :hidden_count => 0} unless resource_hash[res.class.name]
      resource_hash[res.class.name][:items] << res
    end

    scale_types = Seek::Util.scalable_types
    scale_types.each do |type|
      resource_hash[type.name] = {:items => [], :hidden_count => 0} unless resource_hash[type.name]
    end

    resource_hash.each do |key,res|
      res[:items].compact!
      unless res[:items].empty?
        total_count = res[:items].size
        all = res[:items]
        res[:items] = key.constantize.authorize_asset_collection res[:items], "view"
        res[:hidden_count] = total_count - res[:items].size
        res[:hidden_items] = all - res[:items]
      end
    end

    render :update do |page|
      scale_title = scale.try(:key) || 'all'
      page.replace_html "#{scale_title}_results", :partial=>"assets/resource_listing_tabbed_by_class", :locals =>{:resource_hash=>resource_hash,
                                                                                                                  :show_empty_tabs=>true,
                                                                                                                  :narrow_view => true, :authorization_already_done => true,
                                                                                                                  :limit => 20,
                                                                                                                  :tabs_id => "#{scale_title}_resource_listing_tabbed_by_class",
                                                                                                                  :actions_partial_disable => true, :display_immediately=>true}
      page << "load_tabs();"
    end

  end

  def show
    @scale_key=Scale.find_by_id(params[:id]).try(:key) || "all"
  end

  private

  def everything_with_scale
    Scale.all.collect do |scale|
      scale.assets
    end.flatten.uniq
  end

end
