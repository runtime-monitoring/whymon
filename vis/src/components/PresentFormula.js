import React, { useEffect, useRef } from 'react';
import Box from '@mui/material/Box';
import AceEditor from "react-ace";
import "ace-builds/src-noconflict/mode-java";
import "ace-builds/src-noconflict/mode-mfotl_formula";
import "ace-builds/src-noconflict/theme-tomorrow";
import "ace-builds/src-noconflict/ext-language_tools";

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

export default function PresentFormula ({ formula,
                                          predsWidth,
                                          backgroundColorClass }) {
  const aceEditor = useRef();

  const initEditor = () => {
    return (
      <AceEditor
        ref={aceEditor}
        value={formula}
        mode="mfotl_formula"
        theme="tomorrow"
        name="formula"
        width="100%"
        height="40px"
        fontSize={14}
        showPrintMargin={false}
        showGutter={false}
        highlightActiveLine={false}
        readOnly={true}
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
    backgroundColor(aceEditor, backgroundColorClass);
  }, [aceEditor, backgroundColorClass]);

  return (
    <div>
      <Box sx={{ width: '100%', height: '100%' }}
           className="presentFormula">
        <div style={{"minWidth": predsWidth}}>
          { initEditor() }
        </div>
      </Box>
    </div>
  );
}
