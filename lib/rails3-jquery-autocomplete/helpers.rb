module Rails3JQueryAutocomplete

  # Contains utility methods used by autocomplete
  module Helpers

    # Returns a three keys hash 
    def json_for_autocomplete(items, method)
      items.collect {|item| {"id" => item.id, "label" => item.send(method), "value" => item.send(method)}}
    end

    # Returns parameter model_sym as a constant
    #
    #   get_object(:actor)
    #   # returns a Actor constant supposing it is already defined
    def get_object(model)
      object = model.is_a?(Symbol) ? model.to_s.camelize.constantize : model
    end

    # Returns a symbol representing what implementation should be used to query
    # the database and raises *NotImplementedError* if ORM implementor can not be found
    def get_implementation(pool)
      object = pool.is_a?(Array) ? pool[0] : pool 

      if object.respond_to?(:has_sphinx_indexes?) && object.has_sphinx_indexes?
        :thinking_sphinx
      elsif object.superclass.to_s == 'ActiveRecord::Base'
        :activerecord
      elsif object.included_modules.collect(&:to_s).include?('Mongoid::Document')
        :mongoid
      else
        raise NotImplementedError
      end
    end

    # Returns the order parameter to be used in the query created by get_items
    def get_order(implementation, fields, options)
      order = options[:order]

      case implementation
        when :mongoid then
          if order 
            order.split(',').collect do |fields| 
              sfields = fields.split
              [sfields[0].downcase.to_sym, sfields[1].downcase.to_sym]
            end
          else
            if fields.is_a? Array
              fields.collect{|f| [f.to_sym, :asc] }
            else
              [[fields.to_sym, :asc]]
            end
          end
        when :activerecord, :thinking_sphinx then
          fields = fields.collect{|f| "#{f} ASC" }.join(", ") if fields.is_a? Array
          order = order ? order : fields
          order = nil if order.blank?
      end
    end

    # Returns a limit that will be used on the query    
    def get_limit(options)
      options[:limit] ||= 10
    end
  
    # Gets items from the single model with the adequate db interface
    #
    #   items = get_items_from_single_model(:model => get_object(object), :fields => fields, :term => term, :options => options) 
    def get_items_from_single_model(model, fields, term, options)
      is_full_search = options[:full]

      limit = get_limit(options)
      implementation = get_implementation(model)
      order = get_order(implementation, fields, options)

      case implementation
        when :mongoid
          search = (is_full_search ? '.*' : '^') + term + '.*'
          items = model.where(fields.to_sym => /#{search}/i).limit(limit).order_by(order)
        when :activerecord
          items = model.where(["LOWER(#{fields}) LIKE ?", "#{(is_full_search ? '%' : '')}#{term.downcase}%"]) \
            .limit(limit).order(order)
        when :thinking_sphinx
          query = "#{(is_full_search ? '*' : '')}#{term}*"
          if fields.is_a? Array
            items = model.search(fields.collect{|f| "@#{f.to_sym} #{query}" }.join(" | "), \
                      :match_mode => :boolean, :per_page => limit, :order => order)
          else
            items = model.search(:conditions => {fields => query}, :per_page => limit, :order => order)
          end
      end
    end

    # Gets items from multiple models with the adequate db interface
    #
    #   items = get_items(:pool => search_pool, :options => options, :term => term, :method => method) 
    def get_items_from_multiple_sources(pool_items, term, options)
      is_full_search = options[:full]
      
      limit = get_limit(options)
      implementation = get_implementation(pool_items) 
      order = get_order(implementation, [], options)

      case implementation
        when :mongoid
          search = (is_full_search ? '.*' : '^') + term + '.*'
          items = pool.where(method.to_sym => /#{search}/i).limit(limit).order_by(order)
        when :activerecord
          items = pool.where(["LOWER(#{method}) LIKE ?", "#{(is_full_search ? '%' : '')}#{term.downcase}%"]) \
            .limit(limit).order(order)
        when :thinking_sphinx
          items = ThinkingSphinx.search("#{(is_full_search ? '*' : '')}#{term}*", :classes => pool_items, \
                    :per_page => limit, :order => order)
      end
    end

  end
end

