module Rails3JQueryAutocomplete

  # Inspired on DHH's autocomplete plugin
  # 
  # Usage:
  # 
  # class ProductsController < Admin::BaseController
  #   autocomplete :brand, :name
  # end
  #
  # This will magically generate an action autocomplete_brand_name, so, 
  # don't forget to add it on your routes file
  # 
  #   resources :products do
  #      get :autocomplete_brand_name, :on => :collection
  #   end
  #
  # Now, on your view, all you have to do is have a text field like:
  # 
  #   f.text_field :brand_name, :autocomplete => autocomplete_brand_name_products_path
  #
  #
  module ClassMethods
    def autocomplete(pool_name, pool_items, options = {})
      single_method = !pool_items.is_a?(Array)
      multiple_models = (!single_method and pool_items.none?{|i| i.is_a? Symbol })

      if !single_method and options[:display_value].blank? 
        raise Exception.new("You have to provide a function name with the display_value " \
        "option if you want to search across multiple fields/models")
      end
      
      method_name = single_method ? "#{pool_name}_#{pool_items}" : "#{pool_name}"

      define_method("autocomplete_#{method_name}") do

        term = params[:term]

        if term && !term.empty?
          if multiple_models
            items = get_items_from_multiple_sources(pool_items, term, options)
          else
            items = get_items_from_single_model(get_object(pool_name), pool_items, term, options)
          end
        else
          items = {}
        end

        render :json => json_for_autocomplete(items, options[:display_value] ||= pool_items)
      end
    end
  end

end
