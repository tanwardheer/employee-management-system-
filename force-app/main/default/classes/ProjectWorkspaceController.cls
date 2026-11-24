public with sharing class ProjectWorkspaceController {
    private static final Integer MAX_TEAM_ROWS = 200;

    public class AllocationRow {
        @AuraEnabled public Id allocationId { get; set; }
        @AuraEnabled public String allocationNumber { get; set; }
        @AuraEnabled public String employeeName { get; set; }
        @AuraEnabled public Date allocationStartDate { get; set; }
        @AuraEnabled public Date allocationEndDate { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<AllocationRow> getProjectTeam(Id projectId) {
        if (projectId == null) {
            throw new AuraHandledException('Open a project to view its team.');
        }

        List<Project_Allocation__c> allocations = [
            SELECT Id, Name, Employee__r.Name, Allocation_Start_Date__c,
                Allocation_End_Date__c
            FROM Project_Allocation__c
            WHERE Project__c = :projectId
            WITH USER_MODE
            ORDER BY Allocation_Start_Date__c DESC NULLS LAST, Employee__r.Name ASC
            LIMIT :MAX_TEAM_ROWS
        ];

        List<AllocationRow> rows = new List<AllocationRow>();
        for (Project_Allocation__c allocation : allocations) {
            AllocationRow row = new AllocationRow();
            row.allocationId = allocation.Id;
            row.allocationNumber = allocation.Name;
            row.employeeName = allocation.Employee__r.Name;
            row.allocationStartDate = allocation.Allocation_Start_Date__c;
            row.allocationEndDate = allocation.Allocation_End_Date__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled(cacheable=true)
    public static List<Project_Allocation__c> getEmployeeProjects(Id employeeId) {
        if (employeeId == null) {
            throw new AuraHandledException('Open an employee record to view their projects.');
        }

        return [
            SELECT Id, Name, Project__c, Project__r.Name,
                Project__r.Project_Code__c, Project__r.Project_Status__c,
                Project__r.Client_Name__c, Allocation_Start_Date__c,
                Allocation_End_Date__c
            FROM Project_Allocation__c
            WHERE Employee__c = :employeeId
            WITH USER_MODE
            ORDER BY Allocation_Start_Date__c DESC NULLS LAST, Project__r.Name ASC
            LIMIT :MAX_TEAM_ROWS
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Project_Allocation__c> getProjectAllocations() {
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Project__c,
                Project__r.Name, Project__r.Project_Code__c,
                Project__r.Project_Status__c, Project__r.Client_Name__c,
                Allocation_Start_Date__c, Allocation_End_Date__c
            FROM Project_Allocation__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT :MAX_TEAM_ROWS
        ];
    }
    @AuraEnabled
    public static Id assignEmployeeToProject(
        Id projectId,
        Id employeeId,
        Date allocationStartDate,
        Date allocationEndDate
    ) {
        if (projectId == null || employeeId == null) {
            throw new AuraHandledException('Choose a project and an employee.');
        }
        if (allocationStartDate != null && allocationEndDate != null
            && allocationEndDate < allocationStartDate) {
            throw new AuraHandledException(
                'The allocation end date cannot be before its start date.'
            );
        }

        // Reading the records in user mode respects the current user's object and field access.
        List<Project__c> projects = [
            SELECT Id
            FROM Project__c
            WHERE Id = :projectId
            WITH USER_MODE
            LIMIT 1
        ];
        if (projects.isEmpty()) {
            throw new AuraHandledException('The selected project could not be found.');
        }

        List<Employee__c> employees = [
            SELECT Id, Employment_Status__c
            FROM Employee__c
            WHERE Id = :employeeId
            WITH USER_MODE
            LIMIT 1
        ];
        if (employees.isEmpty()) {
            throw new AuraHandledException('The selected employee could not be found.');
        }
        if (employees[0].Employment_Status__c != 'Active') {
            throw new AuraHandledException('Only active employees can be assigned.');
        }

        Date effectiveStartDate = allocationStartDate == null
            ? Date.today()
            : allocationStartDate;
        List<Project_Allocation__c> overlappingAllocations = [
            SELECT Id, Allocation_Start_Date__c
            FROM Project_Allocation__c
            WHERE Project__c = :projectId
                AND Employee__c = :employeeId
                AND (Allocation_End_Date__c = null
                    OR Allocation_End_Date__c >= :effectiveStartDate)
            WITH USER_MODE
        ];
        for (Project_Allocation__c existingAllocation : overlappingAllocations) {
            Boolean startsBeforeProposedEnd = allocationEndDate == null
                || existingAllocation.Allocation_Start_Date__c == null
                || existingAllocation.Allocation_Start_Date__c <= allocationEndDate;
            if (startsBeforeProposedEnd) {
                throw new AuraHandledException(
                    'This employee already has an overlapping allocation to this project.'
                );
            }
        }

        Project_Allocation__c newAllocation = new Project_Allocation__c(
            Project__c = projectId,
            Employee__c = employeeId,
            Allocation_Start_Date__c = allocationStartDate,
            Allocation_End_Date__c = allocationEndDate
        );
        Database.insert(newAllocation, AccessLevel.USER_MODE);
        return newAllocation.Id;
    }
}


