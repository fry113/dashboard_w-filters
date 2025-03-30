get 'dashboard', to: 'dashboard#index'
get 'dashboard/set_issue_status/:issue_id/:status_id', to: 'dashboard#set_issue_status'
get 'dashboard/set_issue_executor/:issue_id/:executor_id', to: 'dashboard#set_issue_executor'
