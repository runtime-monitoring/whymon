import React from 'react';
import Box from '@mui/material/Box';
import TextField from '@mui/material/TextField';
import MenuItem from '@mui/material/MenuItem';

const measures = [
  {
    value: "size",
    label: "Size",
  },
  {
    value: "minreach",
    label: "Minimum Reach",
  },
  {
    value: "maxreach",
    label: "Maximum Reach",
  }
]

export default class MeasureSelect extends React.Component {
  render() {
    return (
      <Box
        component="form"
        sx={{
          '& .MuiTextField-root': { width: '100%' },
        }}
        noValidate
        autoComplete="off"
      >
        <div>
          <TextField
            id="outlined-select-measure"
            select
            label="Measure"
          >
            {measures.map((option) => (
              <MenuItem key={option.value} value={option.value}>
                {option.label}
              </MenuItem>
            ))}
          </TextField>
        </div>
      </Box>
    );
  }
}