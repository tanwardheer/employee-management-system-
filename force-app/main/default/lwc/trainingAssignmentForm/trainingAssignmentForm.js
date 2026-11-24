import { LightningElement } from 'lwc';

import assignTrainingWithDueDate from
    '@salesforce/apex/TrainingAssignmentController.assignTrainingWithDueDate';
import assignTrainingToDepartment from
    '@salesforce/apex/TrainingAssignmentController.assignTrainingToDepartment';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const ASSIGNMENT_MODE_OPTIONS = [
    { label: 'One employee', value: 'Employee' },
    { label: 'Entire department', value: 'Department' }
];

const getTodayLocalDate = () => {
    const today = new Date();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');

    return `${today.getFullYear()}-${month}-${day}`;
};

export default class TrainingAssignmentForm extends LightningElement {

    employeeId;
    departmentId;
    trainingId;
    assignmentMode = 'Employee';
    assignmentModeOptions = ASSIGNMENT_MODE_OPTIONS;
    assignedDate = getTodayLocalDate();
    dueDate = '';
    isLoading = false;
    employeeFilter = {
        criteria: [
            {
                fieldPath: 'Employment_Status__c',
                operator: 'eq',
                value: 'Active'
            }
        ]
    };
    trainingFilter = {
        criteria: [
            {
                fieldPath: 'Active__c',
                operator: 'eq',
                value: true
            }
        ]
    };

    get isAssignDisabled() {
        const targetIsMissing = this.assignmentMode === 'Department'
            ? !this.departmentId
            : !this.employeeId;
        return targetIsMissing ||
            !this.trainingId ||
            !this.assignedDate ||
            !this.dueDate ||
            this.dueDate < this.assignedDate ||
            this.isLoading;
    }

    get assignButtonLabel() {
        if (this.isLoading) {
            return 'Assigning...';
        }
        return this.assignmentMode === 'Department'
            ? 'Assign to Department'
            : 'Assign Training';
    }

    get isDepartmentMode() {
        return this.assignmentMode === 'Department';
    }

    get isEmployeeMode() {
        return this.assignmentMode === 'Employee';
    }

    get assignmentInstructions() {
        return this.isDepartmentMode
            ? 'Choose an active department and training program. The due date will apply to each active employee who receives this assignment.'
            : 'Choose an active employee and training program. Set a due date for the new assignment.';
    }

    get dueDateLabel() {
        return this.isDepartmentMode
            ? 'Due Date for Each Employee'
            : 'Due Date';
    }

    handleAssignmentModeChange(event) {
        this.assignmentMode = event.detail.value;
        this.employeeId = null;
        this.departmentId = null;
    }

    handleEmployeeChange(event) {
        this.employeeId = event.detail.recordId;
    }

    handleDepartmentChange(event) {
        this.departmentId = event.detail.recordId;
    }

    handleTrainingChange(event) {
        this.trainingId = event.detail.recordId;
    }

    handleDateChange(event) {
        this.assignedDate = event.target.value;
    }

    handleDueDateChange(event) {
        this.dueDate = event.target.value;
    }

    async handleAssign() {
        if (this.isAssignDisabled) {
            return;
        }

        this.isLoading = true;

        try {
            let successMessage = 'Training assigned successfully.';
            let toastVariant = 'success';
            if (this.isDepartmentMode) {
                const summary = await assignTrainingToDepartment({
                    departmentId: this.departmentId,
                    trainingId: this.trainingId,
                    assignedDate: this.assignedDate,
                    dueDate: this.dueDate
                });
                successMessage =
                    `${summary.assignedCount} assigned, ` +
                    `${summary.duplicateCount} skipped (already assigned), ` +
                    `${summary.failedCount} failed.`;
                if (summary.firstFailureMessage) {
                    successMessage += ` First error: ${summary.firstFailureMessage}`;
                }
                toastVariant = summary.failedCount > 0 ? 'warning' : 'success';
            } else {
                await assignTrainingWithDueDate({
                    employeeId: this.employeeId,
                    trainingId: this.trainingId,
                    assignedDate: this.assignedDate,
                    dueDate: this.dueDate
                });
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.isDepartmentMode
                        ? 'Department assignment complete'
                        : 'Success',
                    message: successMessage,
                    variant: toastVariant
                })
            );

            this.employeeId = null;
            this.departmentId = null;
            this.trainingId = null;
            this.assignedDate = getTodayLocalDate();
            this.dueDate = '';

            this.template.querySelectorAll('lightning-record-picker')
                .forEach(picker => picker.clearSelection());

        } catch (error) {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Assignment Failed',
                    message: error.body?.message || error.message || 'Something went wrong.',
                    variant: 'error'
                })
            );

        } finally {
            this.isLoading = false;
        }
    }
}
