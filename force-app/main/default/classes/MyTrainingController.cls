public with sharing class MyTrainingController {
    private static final String IN_PROGRESS = 'In Progress';
    private static final String COMPLETED = 'Completed';

    @AuraEnabled(cacheable=true)
    public static List<Employee_Training__c> getMyTrainings() {
        Id employeeId = getCurrentEmployeeId();

        return [
            SELECT Id, Training__c, Training__r.Name,
                   Training__r.Training_code__c,
                   Training__r.Training_Category__c,
                   Training__r.Duration_Hours__c, Training__r.Active__c,
                   Assigned_Date__c, Due_Date__c, Training_Status__c,
                   Completion_Date__c, Score__c
            FROM Employee_Training__c
            WHERE Employee__c = :employeeId
            ORDER BY Assigned_Date__c DESC NULLS LAST
        ];
    }

    @AuraEnabled
    public static void updateMyTraining(
        Id assignmentId,
        String newStatus,
        Date completionDate
    ) {
        if (assignmentId == null) {
            throw new AuraHandledException(
                'Please select a training assignment to update.'
            );
        }

        if (newStatus != IN_PROGRESS && newStatus != COMPLETED) {
            throw new AuraHandledException(
                'Training status must be In Progress or Completed.'
            );
        }

        if (newStatus == COMPLETED && completionDate == null) {
            throw new AuraHandledException(
                'Enter a completion date before marking training as completed.'
            );
        }

        if (newStatus == COMPLETED && completionDate > Date.today()) {
            throw new AuraHandledException(
                'Completion date cannot be in the future.'
            );
        }

        Id employeeId = getCurrentEmployeeId();
        List<Employee_Training__c> assignments = [
            SELECT Id
            FROM Employee_Training__c
            WHERE Id = :assignmentId AND Employee__c = :employeeId
            LIMIT 1
        ];

        if (assignments.isEmpty()) {
            throw new AuraHandledException(
                'This training assignment could not be found for your account.'
            );
        }

        // Only these two fields are written. Employees cannot submit a score.
        update new Employee_Training__c(
            Id = assignments[0].Id,
            Training_Status__c = newStatus,
            Completion_Date__c = newStatus == COMPLETED ? completionDate : null
        );
    }

    private static Id getCurrentEmployeeId() {
        List<Employee__c> employees = [
            SELECT Id
            FROM Employee__c
            WHERE Salesforce_user__c = :UserInfo.getUserId()
            LIMIT 2
        ];

        if (employees.isEmpty()) {
            throw new AuraHandledException(
                'Your Salesforce user is not linked to an employee record. Contact HR.'
            );
        }

        if (employees.size() > 1) {
            throw new AuraHandledException(
                'Your Salesforce user is linked to multiple employee records. Contact HR.'
            );
        }

        return employees[0].Id;
    }
}
