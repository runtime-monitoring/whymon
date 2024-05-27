import React, { useState, useEffect } from 'react';
import Box from '@mui/material/Box';
import FormControl from '@mui/material/FormControl';
import Select from '@mui/material/Select';
import MenuItem from '@mui/material/MenuItem';
import InputLabel from '@mui/material/InputLabel';
import localJSON from './examples';

const examples = localJSON.examples;

export default function ExampleSelect ({ exampleGroup, setFormState }) {

  const [example, setExample] = useState("");

  const handleChange = (event) => {
    setExample(event.target.value);
  };

  const handleClose = (event) => {
    const result = examples.find( ({ name }) => name === example );
    if (result !== undefined) {
      setFormState({ type: 'setFormulaAndTraceAndSig',
                     formula: result.formula,
                     trace: result.trace,
                     sig: result.sig });
    }
  };

  useEffect(() => {
    const result = examples.find( ({ name }) => name === example );
    if (result !== undefined) {
      setFormState({ type: 'setFormulaAndTraceAndSig',
                     formula: result.formula,
                     trace: result.trace,
                     sig: result.sig });
    }
  }, [example, setFormState]);

  return (
    <Box
      component="form"
      sx={{
        '& .MuiTextField-root': { width: '100%', height: '100%' },
      }}
      noValidate
      autoComplete="off"
    >
      <div>
        <FormControl fullWidth disabled={exampleGroup === ""}>
          <InputLabel id="example-select-label">Example</InputLabel>

          { exampleGroup === "basic" &&
            <Select
              id="example-select"
              label="Example"
              value={example}
              onChange={handleChange}
              onClose={handleClose}
            >
              <MenuItem disabled value="">
                <em>Basic</em>
              </MenuItem>
              <MenuItem value={"negation"}>Negation</MenuItem>
              <MenuItem value={"equality"}>Equality</MenuItem>
              <MenuItem value={"conjunction"}>Conjunction</MenuItem>
              <MenuItem value={"implication"}>Implication</MenuItem>
              <MenuItem value={"exists-sat"}>Exists (Satisfaction)</MenuItem>
              <MenuItem value={"exists-vio"}>Exists (Violation)</MenuItem>
              <MenuItem value={"forall-sat"}>Forall (Satisfaction)</MenuItem>
              <MenuItem value={"forall-vio"}>Forall (Violation)</MenuItem>
              <MenuItem value={"previous"}>Previous</MenuItem>
              <MenuItem value={"once"}>Once</MenuItem>
              <MenuItem value={"since"}>Since</MenuItem>
            </Select>
          }

          { exampleGroup === "case-studies" &&
            <Select
              id="example-select"
              label="Example"
              value={example}
              onChange={handleChange}
              onClose={handleClose}
            >
              <MenuItem disabled value="">
                <em>Case Studies</em>
              </MenuItem>
              <MenuItem value={"three-attempts"}>Three Attempts</MenuItem>
              <MenuItem value={"changed-to"}>Changed To</MenuItem>
              {/* <MenuItem disabled value=""> */}
              {/*   <em>TACAS'24</em> */}
              {/* </MenuItem> */}
              <MenuItem value={"data-race"}>Data Race</MenuItem>
              <MenuItem value={"nokia-del-2-3"}>Database Deletion Propagation</MenuItem>
            </Select>
          }

          { exampleGroup === "misc" &&
            <Select
              id="example-select"
              label="Example"
              value={example}
              onChange={handleChange}
              onClose={handleClose}
            >
              <MenuItem disabled value="">
                <em>Miscellaneous</em>
              </MenuItem>
              <MenuItem value={"publish-approve-manager"}>Publish/Approve/Manager</MenuItem>
              <MenuItem value={"closed-publish-approve-manager"}>Closed Publish/Approve/Manager</MenuItem>
            </Select>
          }


        </FormControl>
      </div>
    </Box>
  );
}
