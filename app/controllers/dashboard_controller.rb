# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    @use_drop_down_menu = Setting.plugin_dashboard['use_drop_down_menu']
    @display_issue_card_author = Setting.plugin_dashboard['display_issue_card_author']
    @selected_project_id  = params[:project_id ].nil? ? -1 : params[:project_id ].to_i
    @selected_executor_id = params[:executor_id].nil? ? -1 : params[:executor_id].to_i
    @selected_view        = params[:view       ].nil? ? '' : params[:view       ].to_s
    @selected_station_id  = params[:station_id ].nil? ? -1 : params[:station_id ].to_i
    show_sub_tasks = Setting.plugin_dashboard['display_child_projects_tasks']
    @show_project_badge = @selected_project_id == -1 || @selected_project_id != -1 && show_sub_tasks
    @use_drag_and_drop = Setting.plugin_dashboard['enable_drag_and_drop']
    @display_minimized_closed_issue_cards = Setting.plugin_dashboard['display_closed_statuses'] ? Setting.plugin_dashboard['display_minimized_closed_issue_cards'] : false
    @statuses   = get_statuses
    @projects   = get_projects
    @executors  = get_executors
    @issues     = get_issues(@selected_project_id, show_sub_tasks)
    @priorities = get_priorities
    @stations   = get_stations(@issues)
  end

  def set_issue_status
    issue_id  = params[:issue_id ].to_i
    status_id = params[:status_id].to_i

    issue = Issue.find(issue_id)

    if issue.new_statuses_allowed_to.select { |item| item.id == status_id }.any?
      issue.init_journal(User.current)
      issue.status_id = status_id
      issue.save
      head :ok
    else
      head :forbidden
    end
  end

  def set_issue_executor
    issue_id    = params[:issue_id   ].to_i
    executor_id = params[:executor_id].to_i

    issue = Issue.find(issue_id)
    if issue.safe_attribute?('assigned_to_id', User.current)
      issue.init_journal(User.current)
      issue.assigned_to_id = executor_id == -2 ? nil : executor_id # check if executor_id is -2 (executor_not_set) and set it to nil
      if issue.save
        Rails.logger.info("Executor for issue ##{issue_id} set to #{executor_id}")
        head :ok
      else
        Rails.logger.error("Failed to save issue ##{issue_id}: #{issue.errors.full_messages.join(', ')}")
        head :unprocessable_entity
      end
    else
      Rails.logger.error("Failed to save issue ##{issue_id}: #{issue.errors.full_messages.join(', ')}")
      head :forbidden
    end
  end

  private

  def get_statuses
    data = {}
    items = Setting.plugin_dashboard['display_closed_statuses'] ? IssueStatus.sorted : IssueStatus.sorted.where('is_closed = false')
    items.each do |item|
      data[item.id] = {
        :name => item.name,
        :color => Setting.plugin_dashboard["status_color_" + item.id.to_s],
        :is_closed => item.is_closed
      }
    end
    data
  end

  def get_projects
    data = {-1 => {
      :name => l(:label_all),
      :color => '#4ec7ff',
      :users => User.active.pluck(:id) # Include all active users for the all projects
    }}

    Project.visible.each do |item|
      data[item.id] = {
        :name => item.name,
        :color => Setting.plugin_dashboard["project_color_" + item.id.to_s],
        :users => item.users.pluck(:id) # get the list of user IDs allowed for this project
      }
      data[item.id][:users].push(-2) unless data[item.id][:users].include?(-2) # add executor_not_set option (additioanlly check for making sure)
    end
    data
  end

  # get all executors
  def get_executors
    data = {
      -2 => { :name => l(:executor_not_set) }, # add executor_not_set option
      -1 => { :name => l(:label_all)        }  # add all_executors option
    }
    User.active.each do |item|
      data[item.id] = {
        :name => item.name
      }
    end
    data
  end

  def get_priorities
    data = {}
    IssuePriority.all.each do |priority|
      data[priority.id] = {
        :name  => priority.name,
        :color => Setting.plugin_dashboard["priority_color_" + priority.id.to_s]
      }
    end
  
    data
  end

  def add_children_ids(id_array, project)
    project.children.each do |child_project|
      id_array.push(child_project.id)
      add_children_ids(id_array, child_project)
    end
  end

  # get all stations from @issues
  def get_stations(issues)
    # init data hash with a default "All" option
    data = {-1 => {
      :name => l(:label_all)
    }}
    # get unique, non-nil, and sorted station names from issues
    tmp = issues.map { |item| item[:station_name] }.uniq.compact.sort
    # add to data w/ [-1 => "All"] hash sorted station names from tmp
    tmp.each_with_index do |item, id|
      data[id] = {
        :name => item
    }
    end
    data
  end

  def get_issues(project_id, with_sub_tasks)
    id_array = []

    if project_id != -1
      id_array.push(project_id)
    end

    # fill array of children ids
    if project_id != -1 && with_sub_tasks
      project = Project.find(project_id)
      add_children_ids(id_array, project)
    end

    items = id_array.empty? ? Issue.visible : Issue.visible.where(:projects => {:id => id_array})

    unless Setting.plugin_dashboard['display_closed_statuses']
      items = items.open
    end

    data = items.map do |item|
      {
        :id => item.id,
        :subject => item.subject,
        :status_id => item.status.id,
        :project_id => item.project.id,
        :created_on => item.created_on,
        :due_date   => item.due_date,
        :overdue => item.overdue?,
        :author => item.author.name(User::USER_FORMATS[:firstname_lastname]),
        :executor => item.assigned_to.nil? ? l(:executor_not_set) : item.assigned_to.name,
        :station_name => item.custom_field_values.select { |cfv| cfv.custom_field.name == 'Станция' }.first.try(:value),
        :railroad_name => item.custom_field_values.select { |cfv| cfv.custom_field.name == 'Дорога' }.first.try(:value),
        :priority => item.priority_id
      }
    end
    # sort by deadline
    data.sort_by { |item| item[:due_date] || Date.new(9999, 12, 31) } # due_date may be unset, in this case used the maximum possible date
  end
end
