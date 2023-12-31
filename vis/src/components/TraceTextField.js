import React, { useState } from 'react';
import Box from '@mui/material/Box';
import Typography from '@mui/material/Typography';
import AceEditor from "react-ace";
import "ace-builds/src-noconflict/mode-mfotl_trace";
import "ace-builds/src-noconflict/theme-tomorrow";
import "ace-builds/src-noconflict/ext-language_tools";

export default function TraceTextField ({ trace, setFormState }) {

  const [isFocused, setIsFocused] = useState(false);

  const editorHeight = (window.innerHeight - 245).toString() + "px";

  const handleChange = (event) => {
    setFormState({ type: 'setTrace', trace: event });
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
        mode="mfotl_trace"
        theme="tomorrow"
        name="trace"
        onChange={handleChange}
        onFocus={handleFocus}
        onBlur={handleBlur}
        width="100%"
        height={editorHeight}
        fontSize={14}
        showPrintMargin={false}
        showGutter={false}
        highlightActiveLine={false}
        value={trace}
        setOptions={{
          enableBasicAutocompletion: false,
          enableLiveAutocompletion: false,
          enableSnippets: false,
          showLineNumbers: false,
          tabSize: 2,
        }}/>
    );
  };

  return (
    <div>
      <Typography variant="h6" position="left">Trace</Typography>
      <Box sx={{ width: '100%', height: '100%' }}
           className={isFocused ? "focusedEditorBox" : "editorBox"}>
        <div className="editor">
          { initEditor() }
        </div>
      </Box>
    </div>
  );
}
