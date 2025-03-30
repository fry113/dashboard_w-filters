// view request types
const REQ_PROJ = 'req_project';
const REQ_EXEC = 'req_executor';
const REQ_VIEW = 'req_viewType';
const REQ_STAT = 'req_station';

// TODO: delete junk

function getUriWithoutDashboard() {
    const reg = new RegExp('(\\/dashboard.*$|\\/$|\\?.*$)');
    let baseUri = location.href;

    if (baseUri.match(reg)!= null) {
        baseUri = baseUri.replace(reg, '');
    }

    return baseUri;
}

function getUriWithDashboard() {
    const baseUri = getUriWithoutDashboard();
    return `${baseUri}/dashboard`;
}

function goToIssue(id) { 
    const baseUri = getUriWithoutDashboard();
    location.href = `${baseUri}/issues/${id}`;
}

function chooseProject(projectId) {
    if (projectId == "-1") {
        location.search = "";
    } else {
        location.search = `project_id=${projectId}`;   
    }
}

function chooseExecutor(executorId) {
    if (executorId == "-1") {
        location.search = "";
    } else {
        location.search = `executor_id=${executorId}`;   
    }
}

function chooseMulti(projectId, executorId) {
    let search = "";
    if (projectId != "-1") {
        search += `project_id=${projectId}`;
    }
    if (executorId != "-1") {
        search += `&executor_id=${executorId}`;
    }
    location.search = search;
}

function makeRequest(req) {
    let search = "";

    // kanban view is default view. otherwise, add view type to search
    let viewType = document.querySelector('#select_view').value;
    if (viewType != "kanban" && viewType != "") {
        search += `view=${viewType}`;
    }

    let projectId = document.querySelector('#select_project').value;
    if (projectId != "-1") {
        search += search.length > 0 ? "&" : "";
        search += `project_id=${projectId}`;
    }

    if (viewType != "person") {
        let executorId = document.querySelector('#select_executor').value;
        if (executorId != "-1") {
            search += search.length > 0 ? "&" : "";
            search += `executor_id=${executorId}`;
        }
    }

    // all stations are default view. otherwise, add station to search
    let stationId = document.querySelector('#select_station').value;
    if (stationId != "-1") {
        search += search.length > 0 ? "&" : "";
        search += `station_id=${stationId}`;
    }
    
    location.search = search;
}

async function setIssueStatus(issueId, statusId, item, oldContainer, oldIndex) { 
    const response = await fetch(`${getUriWithDashboard()}/set_issue_status/${issueId}/${statusId}`);
    if (!response.ok) {
        oldContainer.insertBefore(item, oldContainer.childNodes[oldIndex + 1]);
    }
}

async function setIssueExecutor(issueId, executorId, item, oldContainer, oldIndex) { 
    const response = await fetch(`${getUriWithDashboard()}/set_issue_executor/${issueId}/${executorId}`);
    if (!response.ok) {
        oldContainer.insertBefore(item, oldContainer.childNodes[oldIndex + 1]);
    }
}

function init(useDragAndDrop) {
    document.querySelector('#main-menu').remove();

    // TODO: remove button-type list of projects
    document.querySelectorAll('.select_project_item').forEach(item => {
        item.addEventListener('click', function() {
            chooseProject(this.dataset.id);
        })
    });

    const projectsSelector = document.querySelector('#select_project');
    if (projectsSelector != null) {
        projectsSelector.addEventListener('change', function(e) {
            makeRequest(REQ_PROJ);
        });
    }

    const executorSelector = document.querySelector('#select_executor');
    if (executorSelector != null) {
        executorSelector.addEventListener('change', function(e) {
            makeRequest(REQ_EXEC);
        });
    }

    const viewSelector = document.querySelector('#select_view');
    if (viewSelector != null) {
        viewSelector.addEventListener('change', function(e) {
            makeRequest(REQ_VIEW);
        });
    }

    const stationSelector = document.querySelector('#select_station');
    if (stationSelector != null) {
        stationSelector.addEventListener('change', function(e) {
            makeRequest(REQ_STAT);
        });
    }

    document.querySelector("#content").style.overflow = "hidden"; 

    if (useDragAndDrop) {
        document.querySelectorAll('.status_column_closed_issues, .status_column_issues').forEach(item => {
            new Sortable(item, {
                group: 'issues',
                animation: 150,
                draggable: '.issue_card',
                onEnd: async function(evt) {
                    const newStatus = evt.to.closest('.status_column').dataset.id;
                    const issueId = evt.item.dataset.id;
                    let viewSelector = document.querySelector('#select_view');
                    viewSelector = viewSelector != null ? viewSelector.value : "kanban";
                    if (     viewSelector == "kanban") await setIssueStatus(  issueId, newStatus, evt.item, evt.from, evt.oldIndex);
                    else if (viewSelector == "person") await setIssueExecutor(issueId, newStatus, evt.item, evt.from, evt.oldIndex);
                }
            })
        })
    }
}