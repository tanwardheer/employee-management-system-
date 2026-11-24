public with sharing class HRTrainingController {
    private static final Set<String> ALLOWED_TRAINING_STATUSES = new Set<String>{
        'Assigned', 'In Progress', 'Completed'
    };
    private static final Set<String> ALLOWED_DUE_FILTERS = new Set<String>{
        'Overdue', 'Due Soon', 'On Track', 'No Due Date'
    };
    private static final Integer MAX_RESULTS = 200;

    public class ScoreUpdate {
        @AuraEnabled public Id assignmentId { get; set; }
        @AuraEnabled public Decimal score { get; set; }
    }

    public class ResultUpdate {
        @AuraEnabled public Id assignmentId { get; set; }
        @AuraEnabled public Boolean updateScore { get; set; }
        @AuraEnabled public Decimal score { get; set; }
        @AuraEnabled public Boolean updateDueDate { get; set; }
        @AuraEnabled public Date dueDate { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<Employee_Training__c> getAssignments(
        Id employeeId,
        Id trainingId,
        String statusFilter
    ) {
        requireHrPermission();

        if (String.isNotBlank(statusFilter) && statusFilter != 'All'
            && !ALLOWED_TRAINING_STATUSES.contains(statusFilter)
            && !ALLOWED_DUE_FILTERS.contains(statusFilter)) {
            throw new AuraHandledException('Choose a valid training or due-date status.');
        }

        String queryText =
            'SELECT Id, Employee__c, Employee__r.Name, Employee__r.Employee_code__c, '
            + 'Training__c, Training__r.Name, Training__r.Training_Category__c, '
            + 'Assigned_Date__c, Due_Date__c, Training_Status__c, Completion_Date__c, Score__c '
            + 'FROM Employee_Training__c WHERE Id != null';
        Date today = Date.today();
        Date dueSoonLimit = today.addDays(7);
        if (employeeId != null) {
            queryText += ' AND Employee__c = :employeeId';
        }
        if (trainingId != null) {
            queryText += ' AND Training__c = :trainingId';
        }
        if (ALLOWED_TRAINING_STATUSES.contains(statusFilter)) {
            queryText += ' AND Training_Status__c = :statusFilter';
        } else if (ALLOWED_DUE_FILTERS.contains(statusFilter)) {
            if (statusFilter == 'Overdue') {
                queryText += ' AND Training_Status__c != \'Completed\' AND Due_Date__c < :today';
            } else if (statusFilter == 'Due Soon') {
                queryText += ' AND Training_Status__c != \'Completed\' AND Due_Date__c >= :today AND Due_Date__c <= :dueSoonLimit';
            } else if (statusFilter == 'On Track') {
                queryText += ' AND Training_Status__c != \'Completed\' AND Due_Date__c > :dueSoonLimit';
            } else {
                queryText += ' AND Due_Date__c = null';
            }
        }
        queryText += ' ORDER BY Assigned_Date__c DESC NULLS LAST LIMIT :MAX_RESULTS';

        return Database.query(queryText);
    }

    @AuraEnabled
    public static void updateScores(List<ScoreUpdate> updates) {
        if (updates == null) {
            updateResults(null);
            return;
        }

        List<ResultUpdate> resultUpdates = new List<ResultUpdate>();
        for (ScoreUpdate item : updates) {
            ResultUpdate resultUpdate = new ResultUpdate();
            if (item != null) {
                resultUpdate.assignmentId = item.assignmentId;
                resultUpdate.updateScore = true;
                resultUpdate.score = item.score;
            }
            resultUpdates.add(resultUpdate);
        }
        updateResults(resultUpdates);
    }

    @AuraEnabled
    public static void updateResults(List<ResultUpdate> updates) {
        requireHrPermission();
        if (updates == null || updates.isEmpty()) {
            throw new AuraHandledException('Select at least one result to save.');
        }

        Set<Id> assignmentIds = new Set<Id>();
        Map<Id, ResultUpdate> updatesByAssignment = new Map<Id, ResultUpdate>();
        for (ResultUpdate item : updates) {
            if (item == null || item.assignmentId == null) {
                throw new AuraHandledException('Each result needs a training assignment.');
            }
            if (updatesByAssignment.containsKey(item.assignmentId)) {
                throw new AuraHandledException('A training assignment was included more than once.');
            }
            if (item.updateScore != true && item.updateDueDate != true) {
                throw new AuraHandledException('Choose a score or due date to update.');
            }
            if (item.updateScore == true && item.score != null
                && (item.score < 0 || item.score > 100)) {
                throw new AuraHandledException('Scores must be between 0 and 100.');
            }
            assignmentIds.add(item.assignmentId);
            updatesByAssignment.put(item.assignmentId, item);
        }

        List<Employee_Training__c> assignments = [
            SELECT Id
            FROM Employee_Training__c
            WHERE Id IN :assignmentIds
            FOR UPDATE
        ];
        if (assignments.size() != assignmentIds.size()) {
            throw new AuraHandledException('One or more training assignments could not be found.');
        }

        for (Employee_Training__c assignment : assignments) {
            ResultUpdate item = updatesByAssignment.get(assignment.Id);
            if (item.updateScore == true) {
                assignment.Score__c = item.score;
            }
            if (item.updateDueDate == true) {
                assignment.Due_Date__c = item.dueDate;
            }
        }
        update assignments;
    }

    private static void requireHrPermission() {
        if (!FeatureManagement.checkPermission('Manage_Training_Scores')) {
            throw new AuraHandledException(
                'You do not have permission to view or edit HR training results.'
            );
        }
    }
}
