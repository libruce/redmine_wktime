require_dependency "../app/helpers/timelog_helper"
require "application_helper"
module TimelogHelper
	
	def format_criteria_value(criteria_options, value)
		if value.blank?
			"[#{l(:label_none)}]"
		elsif k = criteria_options[:klass]
			obj = k.find_by_id(value.to_i)
			if obj.is_a?(Issue)
				obj.visible? ? "#{obj.tracker} ##{obj.id}: #{obj.subject}" : "##{obj.id}"
			elsif obj.is_a?(WkInventoryItem)
				brandName = obj.product_item.brand.blank? ? "" : obj.product_item.brand.name
				modelName = obj.product_item.product_model.blank? ? "" : obj.product_item.product_model.name
				str = "#{obj.product_item.product.name} - #{brandName} - #{modelName}"
				assetObj = obj.asset_property
				str = str + " - " +assetObj.name unless assetObj.blank?
				str
			else
				obj
			end
		elsif cf = criteria_options[:custom_field]
			format_value(value, cf)
		else
			value.to_s
		end
	end

	def estimated_hours(filters, criteria)
		if ["project", "issue", "category", "status", "version", "tracker", "total"].include?(criteria)
			query = Issue.reorder(nil).all
			filters.each do |filter|
				case filter.first
				when "project"
					query = get_clause(query, filter.last, "project_id")
				when "issue"
					query = get_clause(query, filter.last, "id")
				when "status"
					query = get_clause(query, filter.last, "status_id")
				when "version"
					query = get_clause(query, filter.last, "fixed_version_id")
				when "tracker"
					query = get_clause(query, filter.last, "tracker_id")
				when "category"
					query = get_clause(query, filter.last, "category_id")
				end
			end
			sum = query.sum(:estimated_hours)
		end
		sum || 0
	end

	def estimated_total_hours(filter)
		estimated_hours({ filter[:criteria] => filter[:values].join(",") }, "total")
	end

	def get_clause(query, filter, column)
		condition = filter.present? ? ((filter.split(",")).include?("null") ? "#{column} IN (#{filter}) OR #{column} IS NULL" : "#{column} IN (#{filter})") : "#{column} IS NULL"
		query = query.where(condition)
	end
end