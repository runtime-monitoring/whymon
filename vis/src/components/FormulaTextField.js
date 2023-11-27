import React, { useState, useEffect, useRef } from 'react';
import Box from '@mui/material/Box';
import Typography from '@mui/material/Typography';
import AceEditor from "react-ace";
import "ace-builds/src-noconflict/mode-java";
import "ace-builds/src-noconflict/mode-mfotl_formula";
import "ace-builds/src-noconflict/theme-tomorrow";
import "ace-builds/src-noconflict/ext-language_tools";
import Keyboard from "react-simple-keyboard";
import "react-simple-keyboard/build/css/index.css";
import "../keyboard.css";
import { positionToIndex } from '../util';

export default function FormulaTextField ({ formula, setFormState, fixParameters }) {

  const [cursorIndex, setCursorIndex] = useState({ row: 0, column: 0 });

  const traceEditorHeight = window.innerHeight - 245;
  const editorHeight = fixParameters ? "113px"
        : ((traceEditorHeight / 2) - 30).toString() + "px";

  const aceEditor = useRef();
  const keyboard = useRef();

  const handleKeyboardChange = input => {
    // console.log(aceEditor.current.editor);
    aceEditor.current.editor.gotoLine(cursorIndex.row, cursorIndex.column);
    setFormState({ type: 'setFormula', formula: input });
    // keyboard.current.setCaretPosition(cursorIndex+1);
    // aceEditor.current.editor.textInput.focus()
  };

  const handleChange = (event) => {
    const input = event;
    setFormState({ type: 'setFormula', formula: input });
    keyboard.current.setInput(input);
  };

  const handleCursorChange = (event) => {
    // console.log(event);
    let index = positionToIndex(event.cursor.row, event.cursor.column, event.doc.$lines);
    setCursorIndex({ row: event.cursor.row, column: event.cursor.column });
    keyboard.current.setCaretPosition(index);
    console.log("row = " + event.cursor.row + "; col = " + event.cursor.column + "; index = " + formula[index]);
  };

  const initEditor = () => {
    return (
      <AceEditor
        ref={aceEditor}
        mode="mfotl_formula"
        theme="tomorrow"
        name="formula"
        onChange={handleChange}
        onCursorChange={handleCursorChange}
        width="100%"
        height={editorHeight}
        fontSize={14}
        showPrintMargin={false}
        showGutter={false}
        highlightActiveLine={false}
        value={formula}
        readOnly={fixParameters}
        highlightIndentGuides={false}
        setOptions={{
          enableBasicAutocompletion: false,
          enableLiveAutocompletion: false,
          enableSnippets: false,
          showLineNumbers: false,
          tabSize: 2,
        }}/>
    );
  };

  useEffect(() => {
    keyboard.current.setInput(formula);
    // aceEditor.current.editor.gotoLine();
    // keyboard.current.setCaretPosition(cursorIndex);
  }, [formula, cursorIndex]);

  return (
    <div>
      { !fixParameters && <Typography variant="h6" position="left">Formula</Typography> }
      <Box sx={{ width: '100%', height: '100%' }}
           className="editorBox">
        <div className="editor">
          { initEditor() }
        </div>
      </Box>
      <div className={`keyboardContainer ${fixParameters ? "hidden" : ""}`}>
        <Keyboard
          keyboardRef={r => { (keyboard.current = r); } }
          layoutName={"default"}
          onChange={handleKeyboardChange}
          preventMouseDownDefault={true}
          layout={{
            default: ["∞ ⊤ ⊥ = ¬ ∧ ∨ → ↔ ∃ ∀ ● ○ ⧫ ◊ ■ □ S U"]
          }}
          /* disableCaretPositioning={true} */
        />
      </div>
    </div>
  );
}
