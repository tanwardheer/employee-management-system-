import { createElement } from '@lwc/engine-dom';
import { createApexTestWireAdapter as mockCreateApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';
import MyTraining from 'c/myTraining';
import getMyTrainings from '@salesforce/apex/MyTrainingController.getMyTrainings';
import updateMyTraining from '@salesforce/apex/MyTrainingController.updateMyTraining';

jest.mock('@salesforce/apex/MyTrainingController.getMyTrainings', () => ({
    default: mockCreateApexTestWireAdapter(jest.fn())
}), { virtual: true });
jest.mock('@salesforce/apex/MyTrainingController.updateMyTraining', () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe('c-my-training', () => {
    afterEach(() => { document.body.innerHTML = ''; jest.clearAllMocks(); });

    it('renders records from the current employee training wire', async () => {
        const element = createElement('c-my-training', { is: MyTraining });
        document.body.appendChild(element);
        getMyTrainings.emit([{ Id: 'a-1', Training_Status__c: 'Assigned', Training__r: { Name: 'Safety' } }]);
        await flushPromises();
        expect(element.shadowRoot.textContent).toContain('Safety');
        expect(element.shadowRoot.textContent).toContain('Not specified');
    });

    it('updates status and completion date for the selected assignment', async () => {
        updateMyTraining.mockResolvedValue();
        const element = createElement('c-my-training', { is: MyTraining });
        document.body.appendChild(element);
        getMyTrainings.emit([{ Id: 'a-2', Training_Status__c: 'In Progress', Training__r: { Name: 'Course' } }]);
        await flushPromises();
        const completionDate = element.shadowRoot.querySelector('lightning-input');
        completionDate.setAttribute('data-assignment-id', 'a-2');
        completionDate.setAttribute('data-field', 'completionDate');
        completionDate.dispatchEvent(new CustomEvent('change', { detail: { value: '2026-11-20' } }));
        const save = element.shadowRoot.querySelector('lightning-button');
        save.setAttribute('data-assignment-id', 'a-2');
        save.click();
        await flushPromises();
        expect(updateMyTraining).toHaveBeenCalledWith({
            assignmentId: 'a-2', newStatus: 'In Progress', completionDate: '2026-11-20'
        });
    });
});
