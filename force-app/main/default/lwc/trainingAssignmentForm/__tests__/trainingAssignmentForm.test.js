import { createElement } from '@lwc/engine-dom';
import TrainingAssignmentForm from 'c/trainingAssignmentForm';
import assignTrainingWithDueDate from '@salesforce/apex/TrainingAssignmentController.assignTrainingWithDueDate';
import assignTrainingToDepartment from '@salesforce/apex/TrainingAssignmentController.assignTrainingToDepartment';

jest.mock(
    '@salesforce/apex/TrainingAssignmentController.assignTrainingWithDueDate',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/TrainingAssignmentController.assignTrainingToDepartment',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe('c-training-assignment-form', () => {
    afterEach(() => {
        document.body.innerHTML = '';
        jest.clearAllMocks();
    });

    it('requires employee, training, assigned date, and due date', () => {
        const element = createElement('c-training-assignment-form', { is: TrainingAssignmentForm });
        document.body.appendChild(element);

        expect(element.shadowRoot.querySelector('lightning-button').disabled).toBe(true);
        expect(element.shadowRoot.querySelector('lightning-record-picker').filter.criteria[0].value)
            .toBe('Active');
    });

    it('sends a valid employee assignment and reports success', async () => {
        assignTrainingWithDueDate.mockResolvedValue();
        const element = createElement('c-training-assignment-form', { is: TrainingAssignmentForm });
        document.body.appendChild(element);
        const pickers = element.shadowRoot.querySelectorAll('lightning-record-picker');
        pickers[0].dispatchEvent(new CustomEvent('change', { detail: { recordId: 'employee-1' } }));
        pickers[1].dispatchEvent(new CustomEvent('change', { detail: { recordId: 'training-1' } }));
        const dateInputs = element.shadowRoot.querySelectorAll('lightning-input');
        dateInputs[0].value = '2026-01-01';
        dateInputs[0].dispatchEvent(new Event('change'));
        dateInputs[1].value = '2026-02-01';
        dateInputs[1].dispatchEvent(new Event('change'));
        await flushPromises();

        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();

        expect(assignTrainingWithDueDate).toHaveBeenCalledWith(expect.objectContaining({
            employeeId: 'employee-1', trainingId: 'training-1',
            assignedDate: '2026-01-01', dueDate: '2026-02-01'
        }));
        expect(element.shadowRoot.querySelector('lightning-button').disabled).toBe(true);
    });

    it('routes department assignments through the bulk Apex action', async () => {
        assignTrainingToDepartment.mockResolvedValue({ assignedCount: 2, duplicateCount: 1, failedCount: 0 });
        const element = createElement('c-training-assignment-form', { is: TrainingAssignmentForm });
        document.body.appendChild(element);
        const mode = element.shadowRoot.querySelector('lightning-combobox');
        mode.dispatchEvent(new CustomEvent('change', { detail: { value: 'Department' } }));
        await flushPromises();
        const pickers = element.shadowRoot.querySelectorAll('lightning-record-picker');
        pickers[0].dispatchEvent(new CustomEvent('change', { detail: { recordId: 'department-1' } }));
        pickers[1].dispatchEvent(new CustomEvent('change', { detail: { recordId: 'training-1' } }));
        const dateInputs = element.shadowRoot.querySelectorAll('lightning-input');
        dateInputs[0].value = '2026-01-01';
        dateInputs[0].dispatchEvent(new Event('change'));
        dateInputs[1].value = '2026-02-01';
        dateInputs[1].dispatchEvent(new Event('change'));
        await flushPromises();
        element.shadowRoot.querySelector('lightning-button').click();
        await flushPromises();

        expect(assignTrainingToDepartment).toHaveBeenCalledWith(expect.objectContaining({
            departmentId: 'department-1', trainingId: 'training-1'
        }));
        expect(assignTrainingWithDueDate).not.toHaveBeenCalled();
    });
});
