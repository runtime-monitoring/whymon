import React from 'react';
import Box from '@mui/material/Box';
import InputLabel from '@mui/material/InputLabel';
import MenuItem from '@mui/material/MenuItem';
import FormControl from '@mui/material/FormControl';
import Select from '@mui/material/Select';

export default function ExampleGroupSelect({ exampleGroup, setExampleGroup }) {

  const handleChange = (event) => {
    setExampleGroup(event.target.value);
  };

  return (
    <Box
      component="form"
      sx={{
        '& .MuiTextField-root': { width: '100%', height: '100%' },
      }}
      noValidate
      autoComplete="off"
    >
      <FormControl fullWidth>
        <InputLabel id="example-group-select-input-label">Example Group</InputLabel>
        <Select
          labelId="example-group-select-label"
          id="example-group-select"
          value={exampleGroup}
          label="Example Group"
          onChange={handleChange}
        >
          <MenuItem value={"basic"}>Basic</MenuItem>
          <MenuItem value={"case-studies"}>Case Studies</MenuItem>
          <MenuItem value={"misc"}>Miscellaneous</MenuItem>
        </Select>
      </FormControl>
    </Box>
  );
}
