import React, {useLayoutEffect, useRef, useState} from 'react';
import {createRoot} from 'react-dom/client';
import {flushSync} from 'react-dom';

const initial = {textarea: 'initial textarea', input: 'initial input', contenteditable: 'initial editable'};
const ids = {textarea: 'controlled-textarea', input: 'controlled-input', contenteditable: 'controlled-contenteditable'};
window.fixtureReady = false;

function Fixture() {
  const [values, setValues] = useState({...initial});
  const [changes, setChanges] = useState({textarea: 0, input: 0, contenteditable: 0});
  const [revision, setRevision] = useState(0);
  const [rejectChanges, setRejectChanges] = useState(false);
  const renders = useRef(0);
  const editable = useRef(null);
  const rollbackProbe = useRef({armed: false, inputObserved: false, applied: false});
  renders.current += 1;
  const renderGeneration = renders.current;
  const validation = Object.fromEntries(Object.keys(initial).map(key => [key, {
    changedFromInitial: values[key] !== initial[key],
    valid: values[key].trim().length >= 3 && values[key] !== initial[key],
    length: values[key].length,
  }]));
  function changed(key, value) {
    setChanges(previous => ({...previous, [key]: previous[key] + 1}));
    if (rejectChanges) { setRevision(previous => previous + 1); return; }
    setValues(previous => ({...previous, [key]: value}));
  }
  useLayoutEffect(() => {
    // React has no built-in controlled contenteditable value prop. This fixture
    // owns its state explicitly, so every committed render restores that state.
    if (editable.current.textContent !== values.contenteditable) {
      editable.current.textContent = values.contenteditable;
    }
    window.fixture204 = {
      read() {
        const domValues = Object.fromEntries(Object.entries(ids).map(([key, id]) => {
          const node = document.getElementById(id);
          return [key, key === 'contenteditable' ? node.textContent : node.value];
        }));
        return {ready: true, generation: document.documentElement.dataset.loadId,
          reactVersion: React.version, renderGeneration, revision, rejectChanges,
          values: {...values}, changes: {...changes}, validation, rollbackProbe: {...rollbackProbe.current},
          domValues, stateMatchesDOM: Object.keys(values).every(key => values[key] === domValues[key])};
      },
      forceRerender() {
        flushSync(() => setRevision(value => value + 1));
        return window.fixture204.read();
      },
      armQueuedDOMRollback() {
        const element = document.getElementById(ids.input);
        const previous = element.value;
        rollbackProbe.current = {armed: true, inputObserved: false, applied: false};
        element.addEventListener('input', () => {
          rollbackProbe.current.inputObserved = true;
          rollbackProbe.current.immediateDOMValue = element.value;
          // Isolated negative control: after React has processed the real input
          // event, an application-owned asynchronous job overwrites only DOM.
          // This is not an alternate implementation of Triton input.
          setTimeout(() => {
            rollbackProbe.current.stateBeforeRollback = window.fixture204.read().values.input;
            element.value = previous;
            rollbackProbe.current.applied = true;
            rollbackProbe.current.restoredDOMValue = element.value;
          }, 0);
        }, {once: true});
        return window.fixture204.read();
      },
      setRejectChanges(value) {
        flushSync(() => setRejectChanges(Boolean(value)));
        return window.fixture204.read();
      },
      reset() {
        flushSync(() => {
          setRejectChanges(false);
          setValues({...initial});
          setChanges({textarea: 0, input: 0, contenteditable: 0});
          setRevision(value => value + 1);
        });
        return window.fixture204.read();
      },
    };
    document.documentElement.dataset.ready = 'true';
    document.documentElement.dataset.renderGeneration = String(renderGeneration);
    window.fixtureReady = true;
  });
  return <main>
    <h1>Controlled input acceptance</h1>
    <p>Offline React {React.version}; generation <span id="load-generation">{document.documentElement.dataset.loadId}</span></p>
    <label htmlFor={ids.textarea}>Controlled textarea</label>
    <textarea id={ids.textarea} rows={3} value={values.textarea}
      onChange={event => changed('textarea', event.target.value)} />
    <label htmlFor={ids.input}>Controlled input</label>
    <input id={ids.input} type="text" value={values.input}
      onChange={event => changed('input', event.target.value)} />
    <label id="editable-label">Controlled contenteditable</label>
    <div id={ids.contenteditable} ref={editable} contentEditable suppressContentEditableWarning
      role="textbox" aria-labelledby="editable-label"
      onInput={event => changed('contenteditable', event.currentTarget.textContent)} />
    <button id="force-rerender" onClick={() => setRevision(value => value + 1)}>Force rerender</button>
    <output id="fixture-status">{JSON.stringify({values, changes, validation, renderGeneration, revision})}</output>
  </main>;
}

createRoot(document.getElementById('root')).render(<Fixture />);
