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

const backgroundColor = (aceEditor, backgroundColorClass) => {
  let colorClasses = ["blueGrey100Background", "amber200Background", "teal100Background"];

  if (aceEditor.current) {
    if (backgroundColorClass && backgroundColorClass.length > 0) {
      for (let i = 0; i < colorClasses.length; ++i) {
        if (aceEditor.current.editor.container.classList.contains(colorClasses[i])) {
          aceEditor.current.editor.container.classList.remove(colorClasses[i]);
        }
      }

      aceEditor.current.editor.container.classList.add(backgroundColorClass);
    } else {
      for (let i = 0; i < colorClasses.length; ++i) {
        if (aceEditor.current.editor.container.classList.contains(colorClasses[i])) {
          aceEditor.current.editor.container.classList.remove(colorClasses[i]);
        }
      }
    }
  }
};

export default function FormulaTextField ({ formula,
                                            setFormState,
                                            fixParameters,
                                            presentFormula,
                                            predsWidth,
                                            backgroundColorClass }) {

  const [isFocused, setIsFocused] = useState(false);

  const traceEditorHeight = window.innerHeight - 245;
  let editorHeight;

  const aceEditor = useRef();
  const keyboard = useRef();

  if (presentFormula) {
    editorHeight = "40px";
  } else {
    if (fixParameters) {
      editorHeight = "113px";
    } else {
      editorHeight = ((traceEditorHeight / 2) - 30).toString() + "px";
    }
  }

  backgroundColor(aceEditor, backgroundColorClass);

  const chooseBoxClassName = () => {
    if (presentFormula) {
      return "presentFormula";
    } else {
      if (isFocused && !fixParameters) {
        return "focusedEditorBox";
      } else {
        return "editorBox";
      }
    }
  };

  const handleKeyboardChange = input => {
    setFormState({ type: 'setFormula', formula: input });
  };

  const handleChange = (event) => {
    const input = event;
    setFormState({ type: 'setFormula', formula: input });
    keyboard.current.setInput(input);
  };

  const handleFocus = () => {
    setIsFocused(true);
  };

  const handleBlur = () => {
    setIsFocused(false);
  };

  const initEditor = () => {
    return (
      <AceEditor
        ref={aceEditor}
        mode="mfotl_formula"
        theme="tomorrow"
        name="formula"
        onChange={handleChange}
        onFocus={handleFocus}
        onBlur={handleBlur}
        width="100%"
        height={editorHeight}
        fontSize={14}
        showPrintMargin={false}
        showGutter={false}
        highlightActiveLine={false}
        value={formula}
        readOnly={fixParameters || presentFormula}
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
  }, [formula]);

  return (
    <div>
      { !(fixParameters || presentFormula) && <Typography variant="h6" position="left">Formula</Typography> }
      <Box sx={{ width: '100%', height: '100%' }}
           className={chooseBoxClassName()}>
        <div style={{"minWidth": predsWidth}} className={presentFormula ? "" : "editor"}>
          { initEditor() }
        </div>
      </Box>
      <div className={`keyboardContainer ${(fixParameters || presentFormula) ? "hidden" : ""}`}>
        <Keyboard
          keyboardRef={r => (keyboard.current = r) }
          layoutName={"default"}
          onChange={handleKeyboardChange}
          preventMouseDownDefault={true}
          disableCaretPositioning={true}
          layout={{
            default: ["∞ ⊤ ⊥ = ¬ ∧ ∨ → ↔ ∃ ∀ ● ○ ⧫ ◊ ■ □ S U"]
          }}
        />
      </div>
    </div>
  );
}
