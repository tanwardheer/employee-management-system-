@IsTest
private class ProjectWorkspaceControllerTest {
    private static final String EMPLOYEE_CODE = 'PW-TEST-EMP-01';
    private static final String PROJECT_CODE = 'PW-TEST-PROJECT-01';

    @TestSetup
    static void createTestData() {
        departement__c department = new departement__c(
            Name = 'Project Workspace Test Department',
            Department_Code__c = 'PW-TEST-DEPT'
        );
        insert department;

        Employee__c employee = new Employee__c(
            Name = 'Project Workspace Test Employee',
            Employee_code__c = EMPLOYEE_CODE,
            Email__c = 'project.workspace.employee@example.com',
            Phone__c = '555-010-4001',
            Date_of_joining__c = Date.today(),
            Designation__c = 'Analyst',
            Employment_Status__c = 'Active',
            department__c = department.Id
        );
        insert employee;

        Project__c project = new Project__c(
            Name = 'Project Workspace Test Project',
            Project_Code__c = PROJECT_CODE,
            Project_Status__c = 'Planned',
            Client_Name__c = 'Test Client'
        );
        insert project;
    }

    @IsTest
    static void assignsProjectAndReturnsEmployeeAndProjectRows() {
        Employee__c employee = getEmployee();
        Project__c project = getProject();
        Date startDate = Date.today().addDays(2);
        Date endDate = Date.today().addDays(12);

        Test.startTest();
        Id allocationId = ProjectWorkspaceController.assignEmployeeToProject(
            project.Id, employee.Id, startDate, endDate
        );
        List<Project_Allocation__c> employeeRows =
            ProjectWorkspaceController.getEmployeeProjects(employee.Id);
        List<ProjectWorkspaceController.AllocationRow> projectRows =
            ProjectWorkspaceController.getProjectTeam(project.Id);
        List<Project_Allocation__c> allAllocations =
            ProjectWorkspaceController.getProjectAllocations();
        Test.stopTest();

        Project_Allocation__c savedAllocation = [
            SELECT Employee__c, Project__c, Allocation_Start_Date__c,
                Allocation_End_Date__c
            FROM Project_Allocation__c
            WHERE Id = :allocationId
        ];
        System.assertEquals(employee.Id, savedAllocation.Employee__c);
        System.assertEquals(project.Id, savedAllocation.Project__c);
        System.assertEquals(startDate, savedAllocation.Allocation_Start_Date__c);
        System.assertEquals(endDate, savedAllocation.Allocation_End_Date__c);
        System.assertEquals(1, employeeRows.size());
        System.assertEquals(project.Id, employeeRows[0].Project__c);
        System.assertEquals(PROJECT_CODE, employeeRows[0].Project__r.Project_Code__c);
        System.assertEquals(1, allAllocations.size());
        System.assertEquals(employee.Name, allAllocations[0].Employee__r.Name);
        System.assertEquals(project.Name, allAllocations[0].Project__r.Name);
        System.assertEquals(1, projectRows.size());
        System.assertEquals(employee.Name, projectRows[0].employeeName);
        System.assertEquals(startDate, projectRows[0].allocationStartDate);
        System.assertEquals(endDate, projectRows[0].allocationEndDate);
    }

    @IsTest
    static void rejectsMissingIdsAndInvalidDates() {
        Employee__c employee = getEmployee();
        Project__c project = getProject();
        Date today = Date.today();

        System.assertEquals(true, assignmentThrows(null, employee.Id, today, today));
        System.assertEquals(true, assignmentThrows(project.Id, null, today, today));
        System.assertEquals(true, assignmentThrows(UserInfo.getUserId(), employee.Id, today, today));
        System.assertEquals(true, assignmentThrows(project.Id, UserInfo.getUserId(), today, today));
        System.assertEquals(true, assignmentThrows(project.Id, employee.Id, today, today.addDays(-1)));
        System.assertEquals(true, employeeProjectsThrows(null));
        System.assertEquals(true, projectTeamThrows(null));
    }

    @IsTest
    static void allowsBlankAllocationDates() {
        Employee__c employee = getEmployee();
        Project__c project = getProject();

        Id allocationId = ProjectWorkspaceController.assignEmployeeToProject(
            project.Id, employee.Id, null, null
        );
        Project_Allocation__c savedAllocation = [
            SELECT Allocation_Start_Date__c, Allocation_End_Date__c
            FROM Project_Allocation__c
            WHERE Id = :allocationId
        ];

        System.assertEquals(null, savedAllocation.Allocation_Start_Date__c);
        System.assertEquals(null, savedAllocation.Allocation_End_Date__c);
    }
    @IsTest
    static void rejectsInactiveEmployee() {
        Employee__c employee = getEmployee();
        employee.Employment_Status__c = 'Inactive';
        update employee;

        System.assertEquals(
            true,
            assignmentThrows(getProject().Id, employee.Id, Date.today(), null)
        );
        System.assertEquals(0, [SELECT COUNT() FROM Project_Allocation__c]);
    }

    @IsTest
    static void rejectsOverlappingAllocationButAllowsLaterAllocation() {
        Employee__c employee = getEmployee();
        Project__c project = getProject();
        Date firstStart = Date.today().addDays(1);
        Date firstEnd = Date.today().addDays(5);
        ProjectWorkspaceController.assignEmployeeToProject(
            project.Id, employee.Id, firstStart, firstEnd
        );

        System.assertEquals(
            true,
            assignmentThrows(project.Id, employee.Id, firstEnd, firstEnd.addDays(3)),
            'Allocations that overlap on a shared boundary must be rejected.'
        );

        Test.startTest();
        Id laterAllocationId = ProjectWorkspaceController.assignEmployeeToProject(
            project.Id, employee.Id, firstEnd.addDays(1), firstEnd.addDays(10)
        );
        Test.stopTest();

        System.assertNotEquals(null, laterAllocationId);
        System.assertEquals(2, [SELECT COUNT() FROM Project_Allocation__c]);
    }

    private static Employee__c getEmployee() {
        return [
            SELECT Id, Name, Employment_Status__c
            FROM Employee__c
            WHERE Employee_code__c = :EMPLOYEE_CODE
            LIMIT 1
        ];
    }

    private static Project__c getProject() {
        return [
            SELECT Id, Name, Project_Code__c
            FROM Project__c
            WHERE Project_Code__c = :PROJECT_CODE
            LIMIT 1
        ];
    }

    private static Boolean assignmentThrows(Id projectId, Id employeeId, Date startDate, Date endDate) {
        try {
            ProjectWorkspaceController.assignEmployeeToProject(
                projectId, employeeId, startDate, endDate
            );
            return false;
        } catch (AuraHandledException ex) {
            return true;
        }
    }

    private static Boolean employeeProjectsThrows(Id employeeId) {
        try {
            ProjectWorkspaceController.getEmployeeProjects(employeeId);
            return false;
        } catch (AuraHandledException ex) {
            return true;
        }
    }

    private static Boolean projectTeamThrows(Id projectId) {
        try {
            ProjectWorkspaceController.getProjectTeam(projectId);
            return false;
        } catch (AuraHandledException ex) {
            return true;
        }
    }
}





