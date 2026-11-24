import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMyTrainings from '@salesforce/apex/MyTrainingController.getMyTrainings';
import updateMyTraining from '@salesforce/apex/MyTrainingController.updateMyTraining';

const getTodayLocalDate = () => {
    const today = new Date();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');

    return `${today.getFullYear()}-${month}-${day}`;
};

const STATUS_OPTIONS = [
    { label: 'Assigned', value: 'Assigned', disabled: true },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Completed', value: 'Completed' }
];

const FILTER_OPTIONS = [
    { label: 'All trainings', value: 'All' },
    { label: 'Assigned', value: 'Assigned' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Overdue', value: 'Overdue' },
    { label: 'Due soon (today through 7 days)', value: 'Due Soon' },
    { label: 'On track (more than 7 days)', value: 'On Track' },
    { label: 'No due date', value: 'No Due Date' }
];

function getDueDateMessage(assignment) {
    if (!assignment.Due_Date__c) {
        return {
            message: 'No due date set',
            tone: 'slds-text-color_weak',
            filterKey: 'No Due Date'
        };
    }
    if (assignment.Training_Status__c === 'Completed') {
        return {
            message: 'Completed',
            tone: 'slds-text-color_success',
            filterKey: 'Completed'
        };
    }

    const today = getTodayLocalDate();
    const daysRemaining = Math.round(
        (Date.parse(`${assignment.Due_Date__c}T00:00:00Z`) -
            Date.parse(`${today}T00:00:00Z`)) /
            86400000
    );
    if (daysRemaining < 0) {
        const overdueDays = Math.abs(daysRemaining);
        return {
            message: `Overdue by ${overdueDays} ${overdueDays === 1 ? 'day' : 'days'}`,
            tone: 'slds-text-color_error',
            filterKey: 'Overdue'
        };
    }
    if (daysRemaining === 0) {
        return {
            message: 'Due today',
            tone: 'slds-text-color_error',
            filterKey: 'Due Soon'
        };
    }
    if (daysRemaining <= 7) {
        return {
            message: `Due in ${daysRemaining} ${daysRemaining === 1 ? 'day' : 'days'}`,
            tone: 'slds-text-color_warning',
            filterKey: 'Due Soon'
        };
    }
    return {
        message: 'On track',
        tone: 'slds-text-color_success',
        filterKey: 'On Track'
    };
}

export default class MyTraining extends LightningElement {
    assignments = [];
    errorMessage;
    isLoading = true;
    savingAssignmentId;
    wiredAssignments;
    maxCompletionDate = getTodayLocalDate();
    filterOptions = FILTER_OPTIONS;
    statusFilter = 'All';

    @wire(getMyTrainings)
    wiredTrainingList(result) {
        this.wiredAssignments = result;
        if (result.data) {
            this.assignments = result.data.map((assignment) => {
                const dueDateInfo = getDueDateMessage(assignment);
                return {
                    id: assignment.Id,
                    trainingName: assignment.Training__r?.Name || 'Training',
                    trainingCode: assignment.Training__r?.Training_code__c || 'Not specified',
                    trainingCategory:
                        assignment.Training__r?.Training_Category__c || 'Not specified',
                    durationHours:
                        assignment.Training__r?.Duration_Hours__c ?? 'Not specified',
                    programStatus: assignment.Training__r?.Active__c
                        ? 'Active'
                        : 'Inactive',
                    assignedDate: assignment.Assigned_Date__c,
                    dueDate: assignment.Due_Date__c,
                    dueDateMessage: dueDateInfo.message,
                    dueDateTone: dueDateInfo.tone,
                    dueDateFilterKey: dueDateInfo.filterKey,
                    status: assignment.Training_Status__c,
                    completionDate: assignment.Completion_Date__c,
                    score:
                        assignment.Score__c == null
                            ? 'Not recorded'
                            : assignment.Score__c,
                    statusOptions: STATUS_OPTIONS
                };
            });
            this.errorMessage = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage =
                result.error.body?.message || 'Unable to load your trainings.';
            this.assignments = [];
            this.isLoading = false;
        }
    }

    get hasAssignments() {
        return this.assignments.length > 0;
    }

    get filteredAssignments() {
        if (this.statusFilter === 'All') {
            return this.assignments;
        }
        if (['Assigned', 'In Progress', 'Completed'].includes(this.statusFilter)) {
            return this.assignments.filter(
                (assignment) => assignment.status === this.statusFilter
            );
        }
        return this.assignments.filter(
            (assignment) => assignment.dueDateFilterKey === this.statusFilter
        );
    }

    get hasFilteredAssignments() {
        return this.filteredAssignments.length > 0;
    }

    get emptyMessage() {
        return this.hasAssignments
            ? 'No trainings match this status or due-date filter.'
            : 'You do not have any assigned trainings yet.';
    }

    get statusGroups() {
        return [
            { key: 'Completed', label: 'Completed' },
            { key: 'Assigned', label: 'Assigned' },
            { key: 'In Progress', label: 'In Progress' }
        ].map((group) => {
            const groupAssignments = this.filteredAssignments
                .filter((assignment) => assignment.status === group.key)
                .map((assignment) => ({
                    ...assignment,
                    isSaving: this.savingAssignmentId === assignment.id,
                    saveDisabled: Boolean(this.savingAssignmentId),
                    saveLabel:
                        this.savingAssignmentId === assignment.id
                            ? 'Saving...'
                            : 'Save Progress'
                }));

            return {
                ...group,
                assignments: groupAssignments,
                count: groupAssignments.length,
                hasAssignments: groupAssignments.length > 0
            };
        });
    }

    handleFieldChange(event) {
        const assignmentId = event.currentTarget.dataset.assignmentId;
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value;

        this.assignments = this.assignments.map((assignment) =>
            assignment.id === assignmentId
                ? { ...assignment, [field]: value }
                : assignment
        );
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
    }

    async handleSave(event) {
        const assignmentId = event.currentTarget.dataset.assignmentId;
        const assignment = this.assignments.find(
            (item) => item.id === assignmentId
        );
        if (!assignment || this.savingAssignmentId) {
            return;
        }

        this.savingAssignmentId = assignmentId;
        try {
            await updateMyTraining({
                assignmentId,
                newStatus: assignment.status,
                completionDate: assignment.completionDate || null
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Saved',
                    message: 'Your training progress was updated.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredAssignments);
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could Not Save',
                    message:
                        error.body?.message ||
                        error.message ||
                        'Please try again.',
                    variant: 'error'
                })
            );
        } finally {
            this.savingAssignmentId = undefined;
        }
    }
}
