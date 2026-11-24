import { createElement } from '@lwc/engine-dom';
import HrTrainingResults from 'c/hrTrainingResults';
import getAssignments from '@salesforce/apex/HRTrainingController.getAssignments';
import updateResults from '@salesforce/apex/HRTrainingController.updateResults';

jest.mock('@salesforce/apex/HRTrainingController.getAssignments', () => ({
    default: jest.fn()
}), { virtual: true });
jest.mock('@salesforce/apex/HRTrainingController.updateResults', () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe('c-hr-training-results', () => {
    afterEach(() => { document.body.innerHTML = ''; jest.clearAllMocks(); });

    it('loads and maps assignment rows, including fallback relationship values', async () => {
        getAssignments.mockResolvedValue([{ Id: 'row-1', Training_Status__c: 'Assigned', Score__c: null }]);
        const element = createElement('c-hr-training-results', { is: HrTrainingResults });
        document.body.appendChild(element);
        await flushPromises();
        expect(element.shadowRoot.querySelector('lightning-datatable').data[0]).toMatchObject({
            id: 'row-1', employeeName: 'Unknown employee', trainingName: 'Unknown training', score: null
        });
    });

    it('passes edits to Apex and reloads the list', async () => {
        updateResults.mockResolvedValue();
        getAssignments.mockResolvedValue([{ Id: 'row-2', Training_Status__c: 'Assigned' }]);
        const element = createElement('c-hr-training-results', { is: HrTrainingResults });
        document.body.appendChild(element);
        await flushPromises();
        element.shadowRoot.querySelector('lightning-datatable').dispatchEvent(
            new CustomEvent('save', { detail: { draftValues: [{ id: 'row-2', score: 75 }] } })
        );
        await flushPromises();
        expect(updateResults).toHaveBeenCalledWith({ updates: [{
            assignmentId: 'row-2', updateScore: true, score: 75,
            updateDueDate: false, dueDate: null
        }] });
    });

    it('shows an empty state when the result query returns no rows', async () => {
        getAssignments.mockResolvedValue([]);
        const element = createElement('c-hr-training-results', { is: HrTrainingResults });
        document.body.appendChild(element);
        await flushPromises();
        expect(element.shadowRoot.textContent).toContain('No training assignments match these filters.');
    });
});
