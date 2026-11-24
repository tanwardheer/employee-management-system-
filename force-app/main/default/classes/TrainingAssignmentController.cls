
public with sharing class TrainingAssignmentController {

    public class AssignmentSummary {
        @AuraEnabled public Integer assignedCount { get; set; }
        @AuraEnabled public Integer duplicateCount { get; set; }
        @AuraEnabled public Integer failedCount { get; set; }
        @AuraEnabled public String firstFailureMessage { get; set; }
    }

    @AuraEnabled
    public static Id assignTraining(
        Id employeeId,
        Id trainingId,
        Date assignedDate
    ) {
        return createAssignment(employeeId, trainingId, assignedDate, null, false);
    }

    @AuraEnabled
    public static Id assignTrainingWithDueDate(
        Id employeeId,
        Id trainingId,
        Date assignedDate,
        Date dueDate
    ) {
        return createAssignment(employeeId, trainingId, assignedDate, dueDate, true);
    }

    @AuraEnabled
    public static AssignmentSummary assignTrainingToDepartment(
        Id departmentId,
        Id trainingId,
        Date assignedDate,
        Date dueDate
    ) {
        if (departmentId == null || trainingId == null) {
            throw new AuraHandledException(
                'Please select a department and a training.'
            );
        }

        Date effectiveAssignedDate =
            assignedDate != null ? assignedDate : Date.today();
        if (dueDate == null) {
            throw new AuraHandledException('Please enter a due date for this training.');
        }
        if (dueDate < effectiveAssignedDate) {
            throw new AuraHandledException(
                'The due date cannot be earlier than the assigned date.'
            );
        }

        List<Training__c> trainings = [
            SELECT Id, Active__c
            FROM Training__c
            WHERE Id = :trainingId
            LIMIT 1
        ];
        if (trainings.isEmpty()) {
            throw new AuraHandledException(
                'The selected training could not be found.'
            );
        }
        if (!trainings[0].Active__c) {
            throw new AuraHandledException(
                'Only active training programs can be assigned.'
            );
        }

        Integer activeEmployeeCount = [
            SELECT COUNT()
            FROM Employee__c
            WHERE department__c = :departmentId
            AND Employment_Status__c = 'Active'
        ];
        if (activeEmployeeCount == 0) {
            throw new AuraHandledException(
                'This department has no active employees to assign.'
            );
        }
        if (activeEmployeeCount > 10000) {
            throw new AuraHandledException(
                'This department has more than 10,000 active employees. Contact your Salesforce administrator.'
            );
        }

        // Lock the department's active employee rows to prevent concurrent
        // assignments from racing past the duplicate check.
        List<Employee__c> employees = [
            SELECT Id
            FROM Employee__c
            WHERE department__c = :departmentId
            AND Employment_Status__c = 'Active'
            FOR UPDATE
        ];
        if (employees.isEmpty()) {
            throw new AuraHandledException(
                'This department has no active employees to assign.'
            );
        }
        Set<Id> employeeIds = new Map<Id, Employee__c>(employees).keySet();

        Set<Id> alreadyAssignedEmployeeIds = new Set<Id>();
        for (Employee_Training__c existingAssignment : [
            SELECT Employee__c
            FROM Employee_Training__c
            WHERE Training__c = :trainingId
            AND Employee__c IN :employeeIds
        ]) {
            alreadyAssignedEmployeeIds.add(existingAssignment.Employee__c);
        }

        List<Employee_Training__c> newAssignments = new List<Employee_Training__c>();
        for (Employee__c employee : employees) {
            if (!alreadyAssignedEmployeeIds.contains(employee.Id)) {
                newAssignments.add(new Employee_Training__c(
                    Employee__c = employee.Id,
                    Training__c = trainingId,
                    Assigned_Date__c = effectiveAssignedDate,
                    Due_Date__c = dueDate,
                    Training_Status__c = 'Assigned'
                ));
            }
        }

        AssignmentSummary summary = new AssignmentSummary();
        summary.assignedCount = 0;
        summary.duplicateCount = alreadyAssignedEmployeeIds.size();
        summary.failedCount = 0;

        if (newAssignments.isEmpty()) {
            return summary;
        }

        for (Database.SaveResult saveResult : Database.insert(newAssignments, false)) {
            if (saveResult.isSuccess()) {
                summary.assignedCount++;
            } else {
                summary.failedCount++;
                if (summary.firstFailureMessage == null
                    && saveResult.getErrors().size() > 0) {
                    summary.firstFailureMessage = saveResult.getErrors()[0].getMessage();
                }
            }
        }
        return summary;
    }

    private static Id createAssignment(
        Id employeeId,
        Id trainingId,
        Date assignedDate,
        Date dueDate,
        Boolean requireDueDate
    ) {
        if (employeeId == null || trainingId == null) {
            throw new AuraHandledException(
                'Please select an employee and a training.'
            );
        }

        Date effectiveAssignedDate =
            assignedDate != null ? assignedDate : Date.today();
        if (requireDueDate && dueDate == null) {
            throw new AuraHandledException('Please enter a due date for this training.');
        }
        if (requireDueDate && dueDate < effectiveAssignedDate) {
            throw new AuraHandledException(
                'The due date cannot be earlier than the assigned date.'
            );
        }

        // Lock the employee row so concurrent requests for this employee
        // cannot both pass the duplicate check at the same time.
        List<Employee__c> employees = [
            SELECT Id, Employment_Status__c
            FROM Employee__c
            WHERE Id = :employeeId
            LIMIT 1
            FOR UPDATE
        ];

        if (employees.isEmpty()) {
            throw new AuraHandledException(
                'The selected employee could not be found.'
            );
        }

        if (employees[0].Employment_Status__c != 'Active') {
            throw new AuraHandledException(
                'Training can only be assigned to an active employee.'
            );
        }

        List<Training__c> trainings = [
            SELECT Id, Active__c
            FROM Training__c
            WHERE Id = :trainingId
            LIMIT 1
        ];

        if (trainings.isEmpty()) {
            throw new AuraHandledException(
                'The selected training could not be found.'
            );
        }

        if (!trainings[0].Active__c) {
            throw new AuraHandledException(
                'Only active training programs can be assigned.'
            );
        }

        // Check whether this employee already has this training
        List<Employee_Training__c> existingAssignments = [
            SELECT Id
            FROM Employee_Training__c
            WHERE Employee__c = :employeeId
            AND Training__c = :trainingId
            LIMIT 1
        ];

        if (!existingAssignments.isEmpty()) {
            throw new AuraHandledException(
                'This training is already assigned to this employee.'
            );
        }

        Employee_Training__c assignment =
            new Employee_Training__c();

        assignment.Employee__c = employeeId;
        assignment.Training__c = trainingId;
        assignment.Assigned_Date__c = effectiveAssignedDate;
        assignment.Due_Date__c = dueDate;

        assignment.Training_Status__c = 'Assigned';

        insert assignment;

        return assignment.Id;
    }
}
