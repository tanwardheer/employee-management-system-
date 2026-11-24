import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getProjects from '@salesforce/apex/ProjectPortfolioController.getProjects';

const COLUMNS = [
    {
        label: 'Project',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'Name' }, target: '_self' },
        sortable: true
    },
    { label: 'Project Code', fieldName: 'Project_Code__c', type: 'text', sortable: true },
    { label: 'Status', fieldName: 'Project_Status__c', type: 'text', sortable: true },
    { label: 'Client', fieldName: 'Client_Name__c', type: 'text', sortable: true },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local', sortable: true },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local', sortable: true }
];

export default class ProjectPortfolio extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    projects = [];
    searchText = '';
    selectedStatus = 'All';
    error;
    sortedBy = 'Name';
    sortDirection = 'asc';

    @wire(getProjects)
    wiredProjects({ data, error }) {
        if (data) {
            this.projects = data.map((project) => ({
                ...project,
                recordUrl: `/lightning/r/Project__c/${project.Id}/view`
            }));
            this.error = undefined;
        } else if (error) {
            this.projects = [];
            this.error = error;
        }
    }

    get statusOptions() {
        const statuses = [...new Set(this.projects
            .map((project) => project.Project_Status__c)
            .filter(Boolean))]
            .sort((first, second) => first.localeCompare(second));

        return [
            { label: 'All statuses', value: 'All' },
            ...statuses.map((status) => ({ label: status, value: status }))
        ];
    }

    get visibleProjects() {
        const search = this.searchText.trim().toLowerCase();
        return this.projects.filter((project) => {
            const matchesStatus = this.selectedStatus === 'All'
                || project.Project_Status__c === this.selectedStatus;
            const searchableValues = [
                project.Name,
                project.Project_Code__c,
                project.Project_Status__c,
                project.Client_Name__c
            ];
            const matchesSearch = !search || searchableValues.some(
                (value) => value?.toLowerCase().includes(search)
            );
            return matchesStatus && matchesSearch;
        });
    }

    get projectCount() {
        return this.visibleProjects.length;
    }

    get hasProjects() {
        return this.visibleProjects.length > 0;
    }

    get hasError() {
        return Boolean(this.error);
    }

    handleSearch(event) {
        this.searchText = event.target.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortDirection = sortDirection;
        const sortField = fieldName === 'recordUrl' ? 'Name' : fieldName;
        const direction = sortDirection === 'asc' ? 1 : -1;
        this.projects = [...this.projects].sort((first, second) => {
            const left = first[sortField] ?? '';
            const right = second[sortField] ?? '';
            return String(left).localeCompare(String(right), undefined, { numeric: true }) * direction;
        });
    }
}
