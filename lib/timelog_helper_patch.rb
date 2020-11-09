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
		if ["project", "issue", "category", "status", "version", "tracker", "total"].include? criteria
			query = Issue.reorder(nil).all
			filters.each do |filter|
				case filter.first
				when "project"
					query = query.where("project_id IN (#{filter.last})")
				when "issue"
					query = query.where("issues.id IN (#{filter.last})")
				when "status"
					query = query.where("status_id IN (#{filter.last})")
				when "version"
					query = query.where("fixed_version_id " + (filter.last.present? ? "IN (#{filter.last})" : "IS NULL"))
				when "tracker"
					query = query.where("tracker_id IN (#{filter.last})")
				when "category"
					query = query.where("category_id " + (filter.last.present? ? "IN (#{filter.last})" : "IS NULL"))
				end
			end
			sum = query.sum(:estimated_hours)
		end
		sum || 0
	end

	def estimated_total_hours(filter)
		estimated_hours({ filter[:criteria] => filter[:values].join(",") }, "total")
	end
end