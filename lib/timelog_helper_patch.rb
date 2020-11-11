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
		customField = criteria.include?("cf_") ? CustomField.find(criteria.split('_').last) : nil
		if ["project", "issue", "category", "status", "version", "tracker", "user"].include?(criteria) || customField && customField.type == "IssueCustomField"
			query = Issue.reorder(nil)
			query = query.where("project_id = ?", @project.id) if @project.present?
			filters.each do |filter|
				case filter.first
				when "project"
					query = get_clause(query, filter.last, "issues.project_id")
				when "issue"
					query = get_clause(query, filter.last, "issues.id")
				when "status"
					query = get_clause(query, filter.last, "issues.status_id")
				when "version"
					query = get_clause(query, filter.last, "issues.fixed_version_id")
				when "tracker"
					query = get_clause(query, filter.last, "issues.tracker_id")
				when "category"
					query = get_clause(query, filter.last, "issues.category_id")
				when "user"
					query = get_clause(query, filter.last, "issues.assigned_to_id")
				when "cf"
					if filter.last.present? && customField
						query = query.joins(:custom_values).where({ "custom_values.customized_type": "Issue", "custom_values.custom_field_id": customField.id, "custom_values.value": filter.last })
					else
						query = query.joins("LEFT JOIN (
							SELECT customized_id AS id FROM custom_values
							WHERE customized_type = 'Issue' AND (value != '')
							GROUP BY customized_id
							) AS CV ON CV.id = issues.id").where("CV.id IS NULL")
					end
				end
			end
			sum = query.sum(:estimated_hours)
		end
		sum || 0
	end

	def get_clause(query, filter, column)
		condition = filter.present? ? ((filter.split(",")).include?("null") ? "#{column} IN (#{filter}) OR #{column} IS NULL" : "#{column} IN (#{filter})") : "#{column} IS NULL"
		query = query.where(condition)
	end

  def report_to_csv(report)
    Redmine::Export::CSV.generate do |csv|
      # Column headers
      @showEstimate = session[:timelog][:spent_type] == "T" ? true : false
      headers = report.criteria.collect {|criteria| l_or_humanize(report.available_criteria[criteria][:label]) }
      headers += report.periods
      headers << l(:label_total_time)
      headers << l(:field_total_estimated_hours) if @showEstimate
      csv << headers
      # Content
      report_criteria_to_csv(csv, report.available_criteria, report.columns, report.criteria, report.periods, report.hours)
      # Total row
      str_total = l(:label_total_time)
      row = [ str_total ] + [''] * (report.criteria.size - 1)
      total = 0
      report.periods.each do |period|
        sum = sum_hours(select_hours(report.hours, report.columns, period.to_s))
        total += sum
        row << (sum > 0 ? sum : '')
      end
			row << total
			row << @estimatedTotal if @showEstimate
      csv << row
    end
  end

  def report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, hours, level=0, filters = {})
    hours.collect {|h| h[criteria[level]].to_s}.uniq.each do |value|
			hours_for_value = select_hours(hours, criteria[level], value)
			filters.each{|key, value| filters.except!(value) if level < key.to_i}
			criteriaLevel = criteria[level].include?("cf_") ? "cf" : criteria[level]
			filters[level] = criteriaLevel
			filters[criteriaLevel] = value
      next if hours_for_value.empty?
      row = [''] * level
      row << format_criteria_value(available_criteria[criteria[level]], value).to_s
      row += [''] * (criteria.length - level - 1)
			total = 0
      periods.each do |period|
        sum = sum_hours(select_hours(hours_for_value, columns, period.to_s))
        total += sum
        row << (sum > 0 ? sum : '')
      end
			row << total			
			estimatedHours = estimated_hours(filters, criteria[level])
			@estimatedTotal ||= 0
			@estimatedTotal += estimatedHours if level == 0
			row << estimatedHours if @showEstimate
      csv << row
      if criteria.length > level + 1
        report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, hours_for_value, level + 1, filters)
      end
    end
  end
end