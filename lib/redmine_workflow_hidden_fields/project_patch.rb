module RedmineWorkflowHiddenFields
	module  ProjectPatch
		def self.included(base)
			base.send(:include, InstanceMethods)
			base.class_eval do
				unloadable
			end
		end

		module InstanceMethods

			# Returns list of attributes that are hidden on all statuses of all trackers for +user+ or the current user.
			def completely_hidden_attribute_names(user=User.current)
				roles = user.admin ? Role.all : user.roles_for_project(self)

				result = []
				if roles.empty?
					result += Tracker.core_fields(trackers)
					result += self.all_issue_custom_fields.map {|field| field.id.to_s}
				else
					all_hidden_count = roles.size * trackers.size * IssueStatus.all.size
					result += WorkflowPermission.where(
						tracker: trackers,
						old_status: IssueStatus.all,
						role: roles,
						rule: 'hidden'
					).group(:field_name).count(:rule).select{ |field_name, hidden_count|
						hidden_count >= all_hidden_count
					}.map(&:first)
				end
				result += Tracker.disabled_core_fields(trackers)
				result += IssueCustomField.
						  sorted.
						  where("is_for_all = ? AND id NOT IN (SELECT DISTINCT cfp.custom_field_id" +
								" FROM #{table_name_prefix}custom_fields_projects#{table_name_suffix} cfp" +
								" WHERE cfp.project_id = ?)", false, id).map {|field| field.id.to_s}
				result
			end

		end
	end
end
