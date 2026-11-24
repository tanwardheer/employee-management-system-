import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAssignments from '@salesforce/apex/HRTrainingController.getAssignments';
import updateResults from '@salesforce/apex/HRTrainingController.updateResults';

const COLUMNS = [
    { label: 'Employee', fieldName: 'employeeName', type: 'text' },
    { label: 'Employee Code', fieldName: 'employeeCode', type: 'text' },
    { label: 'Training', fieldName: 'trainingName', type: 'text' },
    { label: 'Category', fieldName: 'trainingCategory', type: 'text' },
    { label: 'Assigned Date', fieldName: 'assignedDate', type: 'date' },
    { label: 'Due Date', fieldName: 'dueDate', type: 'date', editable: true },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Completion Date', fieldName: 'completionDate', type: 'date' },
    {
        label: 'Score',
        fieldName: 'score',
        type: 'number',
        editable: true,
        typeAttributes: { min: 0, max: 100, step: 0.01 }
    }
];

const STATUS_OPTIONS = [
    { label: 'All statuses', value: 'All' },
    { label: 'Assigned', value: 'Assigned' },
    { label: 'In Progress', value: 'In Progress' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Overdue (due date)', value: 'Overdue' },
    { label: 'Due soon (due within 7 days)', value: 'Due Soon' },
    { label: 'On track (due in more than 7 days)', value: 'On Track' },
    { label: 'No due date', value: 'No Due Date' }
];

const CSV_COLUMNS = [
    { label: 'Employee', fieldName: 'employeeName' },
    { label: 'Employee Code', fieldName: 'employeeCode' },
    { label: 'Training', fieldName: 'trainingName' },
    { label: 'Category', fieldName: 'trainingCategory' },
    { label: 'Assigned Date', fieldName: 'assignedDate' },
    { label: 'Status', fieldName: 'status' },
    { label: 'Completion Date', fieldName: 'completionDate' },
    { label: 'Score', fieldName: 'score' }
];

function toCsvCell(value) {
    if (value === null || value === undefined) {
        return '""';
    }

    let cellValue = String(value);
    // Prefix formula-like cell content so spreadsheet apps treat it as text.
    if (/^[\s]*[=+@-]/.test(cellValue)) {
        cellValue = `'${cellValue}`;
    }
    return `"${cellValue.replace(/"/g, '""')}"`;
}

export default class HrTrainingResults extends LightningElement {
    columns = COLUMNS;
    statusOptions = STATUS_OPTIONS;
    rows = [];
    drafts = [];
    employeeId;
    trainingId;
    statusFilter = 'All';
    isLoading = false;
    isSaving = false;
    errorMessage;

    connectedCallback() {
        this.loadAssignments();
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get hasDrafts() {
        return this.drafts.length > 0;
    }

    handleEmployeeChange(event) {
        this.employeeId = event.detail.recordId;
        this.loadAssignments();
    }

    handleTrainingChange(event) {
        this.trainingId = event.detail.recordId;
        this.loadAssignments();
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
        this.loadAssignments();
    }

    async loadAssignments() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const assignments = await getAssignments({
                employeeId: this.employeeId || null,
                trainingId: this.trainingId || null,
                statusFilter: this.statusFilter
            });
            this.rows = assignments.map((assignment) => ({
                id: assignment.Id,
                employeeName: assignment.Employee__r?.Name || 'Unknown employee',
                employeeCode:
                    assignment.Employee__r?.Employee_code__c || 'Not specified',
                trainingName: assignment.Training__r?.Name || 'Unknown training',
                trainingCategory:
                    assignment.Training__r?.Training_Category__c || 'Not specified',
                assignedDate: assignment.Assigned_Date__c,
                dueDate: assignment.Due_Date__c,
                status: assignment.Training_Status__c,
                completionDate: assignment.Completion_Date__c,
                score: assignment.Score__c
            }));
            this.drafts = [];
        } catch (error) {
            this.rows = [];
            this.errorMessage =
                error.body?.message || error.message || 'Unable to load training results.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave(event) {
        const changedRows = event.detail.draftValues;
        if (!changedRows?.length || this.isSaving) {
            return;
        }

        this.isSaving = true;
        try {
            await updateResults({
                updates: changedRows.map((row) => ({
                    assignmentId: row.id,
                    updateScore: Object.prototype.hasOwnProperty.call(row, 'score'),
                    score: row.score === '' ? null : row.score,
                    updateDueDate: Object.prototype.hasOwnProperty.call(row, 'dueDate'),
                    dueDate: row.dueDate || null
                }))
            });
            this.drafts = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Training results saved',
                    message: 'Training scores and due dates have been updated.',
                    variant: 'success'
                })
            );
            await this.loadAssignments();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not save training results',
                    message:
                        error.body?.message || error.message || 'Please try again.',
                    variant: 'error'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.drafts = [];
    }

    handleExport() {
        if (!this.rows.length || this.hasDrafts || this.isLoading || this.isSaving) {
            return;
        }

        const csvRows = [
            CSV_COLUMNS.map((column) => toCsvCell(column.label)).join(','),
            ...this.rows.map((row) =>
                CSV_COLUMNS.map((column) => toCsvCell(row[column.fieldName])).join(',')
            )
        ];
        const csvContent = `\uFEFF${csvRows.join('\r\n')}`;
        const dataUri = `data:text/csv;charset=utf-8,${encodeURIComponent(csvContent)}`;
        const downloadLink = document.createElement('a');
        const now = new Date();
        const localDate = [
            now.getFullYear(),
            String(now.getMonth() + 1).padStart(2, '0'),
            String(now.getDate()).padStart(2, '0')
        ].join('-');

        downloadLink.href = dataUri;
        downloadLink.download = `hr-training-results-${localDate}.csv`;
        downloadLink.click();
    }
}
